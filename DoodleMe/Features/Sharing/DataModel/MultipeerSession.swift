//
//  MultipeerSession.swift
//  DoodleMe
//

import Foundation
import MultipeerConnectivity

// MCPeerID 는 만들어진 뒤 바뀌지 않는 값 같은 객체지만 Sendable 선언이 없다.
// 액터 사이로 넘기려면 명시적으로 표시해줘야 한다.
extension MCPeerID: @retroactive @unchecked Sendable {}

/// 가까운 기기끼리 그림을 주고받는다.
///
/// 같은 화면을 연 두 사람이 서로를 자동으로 찾도록, 광고(advertise)와 탐색(browse)을 동시에 켠다.
/// 상대가 초대하면 자동으로 수락한다.
///
/// 화면에는 "연결" 단계가 없다. 보내기를 누르면 필요한 연결까지 알아서 맺고 이어서 보낸다.
///
/// MultipeerConnectivity 의 델리게이트는 임의의 큐에서 불린다.
/// 관찰 대상 상태는 모두 메인 액터에서만 건드리도록 어댑터를 거쳐 넘긴다.
@Observable
@MainActor
final class MultipeerSession {

    /// Bonjour 서비스 이름. 15자 이하, 소문자·숫자·하이픈만 쓸 수 있다.
    /// Info.plist 의 NSBonjourServices 항목과 반드시 같아야 한다.
    static let serviceType = "doodleme"

    /// 한 사람에게 보내는 일이 어디까지 진행됐는지.
    enum TransferState: Equatable {
        case idle
        case sending
        case sent
        case failed(String)
    }

    /// 주변에서 찾은 사람들. 연결되더라도 목록에서 빼지 않는다(화면에 계속 보여야 한다).
    private(set) var peers: [MCPeerID] = []
    private(set) var transferStates: [MCPeerID: TransferState] = [:]
    /// 지금 연결이 맺어져 있는 사람들.
    ///
    /// 받는 쪽에서는 이것이 곧 「상대가 전송을 눌렀다」는 신호다.
    /// 초대는 `send(_:to:)` 안에서만 나가므로, 내가 먼저 보내지 않는 한
    /// 연결이 생겼다는 건 상대가 보내기 시작했다는 뜻이다.
    /// 그냥 주변에 보이기만 하는 `peers` 와 다르다.
    private(set) var connectedPeers: [MCPeerID] = []
    /// 방금 받은 그림. 화면에서 저장한 뒤 nil 로 되돌린다.
    private(set) var received: PostTransferData?
    /// 지금까지 받은 횟수.
    ///
    /// 화면은 이 숫자만 지켜보면 된다.
    /// `received` 값 자체를 비교하면 같은 그림이 두 번 왔을 때 놓치고,
    /// 콜백을 쥐여주면 화면이 세션을 붙잡아 서로를 놓아주지 못한다.
    private(set) var receivedCount = 0
    private(set) var lastError: String?
    /// 주변을 다 훑었는데 아무도 없었는지.
    private(set) var searchTimedOut = false
    /// 로컬 네트워크 권한이 막혀 찾기 자체가 시작되지 못했는지.
    ///
    /// iOS 에는 이 권한의 상태를 직접 묻는 공개 API 가 없다.
    /// 대신 찾기를 시작하지 못했다는 통보가 오면 그것으로 본다.
    private(set) var localNetworkBlocked = false

    /// 상대에게 보이는 내 이름.
    let displayName: String

    @ObservationIgnored private let peerID: MCPeerID
    @ObservationIgnored private let session: MCSession
    @ObservationIgnored private let delegateAdapter: DelegateAdapter
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?
    /// 아직 연결이 안 돼서 기다리고 있는 전송분.
    @ObservationIgnored private var pendingTransfers: [MCPeerID: Data] = [:]
    /// 지금 이 순간 주변에 보이는 사람들.
    ///
    /// `peers` 와 다르다. `peers` 는 결과를 보여주려고 떠난 사람도 남겨두지만,
    /// 이건 실제로 초대를 받을 수 있는 사람만 담는다.
    @ObservationIgnored private var visiblePeers: Set<MCPeerID> = []
    /// 정해진 시간이 지나면 찾기를 멈추는 일감.
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    init(displayName: String) {
        // MCPeerID 는 빈 문자열이나 64자 초과를 허용하지 않는다.
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = trimmed.isEmpty ? Post.unknownSenderName : String(trimmed.prefix(60))
        self.displayName = safeName

        let peerID = Self.storedPeerID(displayName: safeName)
        let adapter = DelegateAdapter()
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = adapter
        adapter.session = session

        self.peerID = peerID
        self.session = session
        self.delegateAdapter = adapter

        // self 가 완전히 초기화된 뒤에 연결한다.
        adapter.owner = self
    }

    /// 이 기기의 고정된 MCPeerID.
    ///
    /// 열 때마다 새로 만들면 같은 기기가 매번 다른 사람으로 보인다.
    /// 상대의 목록에 예전 것이 남아 있으면 이미 사라진 상대에게 초대를 보내게 되고,
    /// 그러면 연결이 맺어지지 않는다. 이름이 바뀌었을 때만 새로 만든다.
    private static func storedPeerID(displayName: String) -> MCPeerID {
        let defaults = UserDefaults.standard
        let idKey = "multipeer.peerID"
        let nameKey = "multipeer.peerName"

        if defaults.string(forKey: nameKey) == displayName,
           let data = defaults.data(forKey: idKey),
           let saved = try? NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: data) {
            return saved
        }

        let peerID = MCPeerID(displayName: displayName)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: peerID, requiringSecureCoding: true) {
            defaults.set(data, forKey: idKey)
            defaults.set(displayName, forKey: nameKey)
        }
        return peerID
    }

    // MARK: - 시작 / 종료

    /// 주변을 찾아보는 시간. 이만큼 지나도 아무도 없으면 그만둔다.
    static let searchWindow: Duration = .seconds(10)

    func start() {
        guard advertiser == nil, browser == nil else { return }

        searchTimedOut = false
        localNetworkBlocked = false

        let advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: nil,
            serviceType: Self.serviceType
        )
        advertiser.delegate = delegateAdapter
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser

        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser.delegate = delegateAdapter
        browser.startBrowsingForPeers()
        self.browser = browser

        // 아무도 없는데 계속 찾으면 배터리만 쓰고 화면은 영영 "찾는중" 에 머문다.
        // 정해진 시간까지만 찾아보고 결과를 알려준다.
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.searchWindow)
            guard !Task.isCancelled, let self, self.peers.isEmpty else { return }
            self.stopSearching()
            self.searchTimedOut = true
        }
    }

    /// 찾기만 멈춘다. 이미 맺은 연결과 목록은 그대로 둔다.
    private func stopSearching() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
    }

    /// 못 찾고 끝난 뒤 다시 찾아본다.
    func searchAgain() {
        stop()
        start()
    }

    func stop() {
        searchTask?.cancel()
        searchTask = nil
        stopSearching()
        session.disconnect()
        peers = []
        connectedPeers = []
        visiblePeers = []
        transferStates = [:]
        pendingTransfers = [:]
    }

    // MARK: - 전송

    func state(for peer: MCPeerID) -> TransferState {
        transferStates[peer] ?? .idle
    }

    /// 한 사람에게 그림을 보낸다. 아직 연결돼 있지 않으면 연결부터 맺고 이어서 보낸다.
    func send(_ transfer: PostTransferData, to peer: MCPeerID) {
        guard state(for: peer) != .sending else { return }

        guard let data = try? transfer.encoded() else {
            transferStates[peer] = .failed("그림을 준비하지 못했어요.")
            return
        }

        transferStates[peer] = .sending

        if session.connectedPeers.contains(peer) {
            deliver(data, to: peer)
        } else if !visiblePeers.contains(peer) {
            // 이미 떠난 사람에게 초대를 보내면 20초를 기다렸다 실패한다.
            // 기다릴 이유가 없으니 바로 알려준다.
            transferStates[peer] = .failed("상대가 화면을 닫은 것 같아요.")
        } else {
            // 연결이 맺어지면 handleStateChange 에서 이어서 보낸다.
            pendingTransfers[peer] = data
            browser?.invitePeer(peer, to: session, withContext: nil, timeout: 20)
        }
    }

    private func deliver(_ data: Data, to peer: MCPeerID) {
        do {
            try session.send(data, toPeers: [peer], with: .reliable)
            transferStates[peer] = .sent
            lastError = nil
        } catch {
            transferStates[peer] = .failed("보내지 못했어요.")
            lastError = error.localizedDescription
        }
    }

    /// 화면에서 저장을 끝낸 뒤 호출한다.
    func clearReceived() {
        received = nil
    }

    // MARK: - 델리게이트 콜백 (메인 액터로 넘어온 뒤 호출됨)

    fileprivate func handleFoundPeer(_ peer: MCPeerID) {
        // 한 명이라도 나타나면 더 이상 실패로 끝낼 일이 없다.
        searchTask?.cancel()
        searchTask = nil
        searchTimedOut = false
        localNetworkBlocked = false
        visiblePeers.insert(peer)
        guard !peers.contains(peer) else { return }
        peers.append(peer)
    }

    fileprivate func handleLostPeer(_ peer: MCPeerID) {
        visiblePeers.remove(peer)
        // 이미 보냈거나 보내는 중이면 결과를 보여줘야 하므로 목록에 남긴다.
        guard state(for: peer) == .idle else { return }
        peers.removeAll { $0 == peer }
    }

    fileprivate func handleStateChange(peer: MCPeerID, state: MCSessionState) {
        switch state {
        case .connected:
            visiblePeers.insert(peer)
            if !peers.contains(peer) { peers.append(peer) }
            if !connectedPeers.contains(peer) { connectedPeers.append(peer) }
            if let waiting = pendingTransfers.removeValue(forKey: peer) {
                deliver(waiting, to: peer)
            }

        case .connecting:
            break

        case .notConnected:
            connectedPeers.removeAll { $0 == peer }
            if pendingTransfers.removeValue(forKey: peer) != nil {
                // 연결을 기다리던 중이었다면 연결 자체가 안 된 것이다.
                transferStates[peer] = .failed("연결하지 못했어요.")
            } else if self.state(for: peer) == .sending {
                // 보내는 도중에 끊겼다. 이대로 두면 계속 "전송중" 에 멈춰 다시 누를 수도 없다.
                transferStates[peer] = .failed("보내는 중에 연결이 끊겼어요.")
            }

        @unknown default:
            break
        }
    }

    fileprivate func handleReceived(_ data: Data) {
        guard let transfer = PostTransferData.decode(from: data) else {
            // 크기가 함께 보여야 빈 데이터인지 형식이 어긋난 건지 가릴 수 있다.
            lastError = "받은 그림을 읽지 못했어요. (\(data.count) 바이트)"
            return
        }
        lastError = nil
        received = transfer
        receivedCount += 1
    }

    fileprivate func handleFailure(_ message: String) {
        lastError = message
    }

    /// 찾기나 알리기를 시작조차 못 했다.
    ///
    /// 권한이 막혔을 때 오는 통보다. 기다릴 이유가 없으니 바로 결과를 보여준다.
    fileprivate func handleStartFailure(_ message: String) {
        lastError = message
        localNetworkBlocked = true
        searchTask?.cancel()
        searchTask = nil
        stopSearching()
    }

    /// MultipeerConnectivity 델리게이트를 받아 메인 액터로 넘겨주는 어댑터.
    ///
    /// `MultipeerSession` 자체를 델리게이트로 삼으면 `@MainActor` 격리와 충돌하므로 분리했다.
    /// 세션 객체들은 Sendable 이 아니지만 만들어진 뒤 교체되지 않고,
    /// 관찰 대상 상태는 전부 메인 액터로 넘겨 건드리므로 `@unchecked Sendable` 이 성립한다.
    private final class DelegateAdapter: NSObject, MCSessionDelegate,
                                         MCNearbyServiceAdvertiserDelegate,
                                         MCNearbyServiceBrowserDelegate, @unchecked Sendable {
        /// init 안에서 한 번만 설정된다.
        nonisolated(unsafe) weak var owner: MultipeerSession?
        /// 초대에 답할 때 넘겨줘야 하므로 약하게 잡으면 안 된다.
        /// 비어 있는 채로 답하면 수락은 되지만 연결이 맺어지지 않고 조용히 끝난다.
        /// MCSession 은 델리게이트를 약하게 잡으므로 순환하지 않는다.
        nonisolated(unsafe) var session: MCSession?

        // MARK: MCSessionDelegate

        nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
            Task { @MainActor [owner] in owner?.handleStateChange(peer: peerID, state: state) }
        }

        nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
            Task { @MainActor [owner] in owner?.handleReceived(data) }
        }

        nonisolated func session(_ session: MCSession, didReceive stream: InputStream,
                                 withName streamName: String, fromPeer peerID: MCPeerID) {}

        nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                                 fromPeer peerID: MCPeerID, with progress: Progress) {}

        nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

        // MARK: MCNearbyServiceAdvertiserDelegate

        nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                    didReceiveInvitationFromPeer peerID: MCPeerID,
                                    withContext context: Data?,
                                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
            // 이 화면을 연 사람끼리만 만나므로 초대를 자동 수락한다.
            // 콜백은 Sendable 이 아니라 액터를 넘길 수 없으므로 이 자리에서 바로 답한다.
            invitationHandler(true, session)
        }

        nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                    didNotStartAdvertisingPeer error: Error) {
            Task { @MainActor [owner] in owner?.handleStartFailure("주변에 알리기 실패: \(error.localizedDescription)") }
        }

        // MARK: MCNearbyServiceBrowserDelegate

        nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                                 withDiscoveryInfo info: [String: String]?) {
            Task { @MainActor [owner] in owner?.handleFoundPeer(peerID) }
        }

        nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
            Task { @MainActor [owner] in owner?.handleLostPeer(peerID) }
        }

        nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
            Task { @MainActor [owner] in owner?.handleStartFailure("주변 찾기 실패: \(error.localizedDescription)") }
        }
    }
}
