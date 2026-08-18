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
    /// 방금 받은 그림. 화면에서 저장한 뒤 nil 로 되돌린다.
    private(set) var received: PostTransferData?
    private(set) var lastError: String?

    /// 그림이 도착하면 바로 부른다.
    ///
    /// 예전에는 화면이 `received` 값의 변화를 지켜보다 저장했다.
    /// 관찰이 한 번이라도 어긋나면 받은 그림이 조용히 사라지므로,
    /// 도착한 그 자리에서 알려주는 편이 확실하다.
    @ObservationIgnored var onReceive: ((PostTransferData) -> Void)?

    /// 상대에게 보이는 내 이름.
    let displayName: String

    @ObservationIgnored private let peerID: MCPeerID
    @ObservationIgnored private let session: MCSession
    @ObservationIgnored private let delegateAdapter: DelegateAdapter
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?
    /// 아직 연결이 안 돼서 기다리고 있는 전송분.
    @ObservationIgnored private var pendingTransfers: [MCPeerID: Data] = [:]

    init(displayName: String) {
        // MCPeerID 는 빈 문자열이나 64자 초과를 허용하지 않는다.
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = trimmed.isEmpty ? "doodle.me 사용자" : String(trimmed.prefix(60))
        self.displayName = safeName

        let peerID = MCPeerID(displayName: safeName)
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

    // MARK: - 시작 / 종료

    func start() {
        guard advertiser == nil, browser == nil else { return }

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
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session.disconnect()
        peers = []
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
        guard !peers.contains(peer) else { return }
        peers.append(peer)
    }

    fileprivate func handleLostPeer(_ peer: MCPeerID) {
        // 이미 보냈거나 보내는 중이면 결과를 보여줘야 하므로 목록에 남긴다.
        guard state(for: peer) == .idle else { return }
        peers.removeAll { $0 == peer }
    }

    fileprivate func handleStateChange(peer: MCPeerID, state: MCSessionState) {
        switch state {
        case .connected:
            if !peers.contains(peer) { peers.append(peer) }
            if let waiting = pendingTransfers.removeValue(forKey: peer) {
                deliver(waiting, to: peer)
            }

        case .connecting:
            break

        case .notConnected:
            // 보내려고 기다리던 중이었다면 연결에 실패한 것이다.
            if pendingTransfers.removeValue(forKey: peer) != nil {
                transferStates[peer] = .failed("연결하지 못했어요.")
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
        onReceive?(transfer)
    }

    fileprivate func handleFailure(_ message: String) {
        lastError = message
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
        nonisolated(unsafe) weak var session: MCSession?

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
            Task { @MainActor [owner] in owner?.handleFailure("주변에 알리기 실패: \(error.localizedDescription)") }
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
            Task { @MainActor [owner] in owner?.handleFailure("주변 찾기 실패: \(error.localizedDescription)") }
        }
    }
}
