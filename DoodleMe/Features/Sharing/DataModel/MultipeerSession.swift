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
/// 상대가 초대하면 자동으로 수락하고, 연결되면 그림을 보낼 수 있다.
///
/// MultipeerConnectivity 의 델리게이트는 임의의 큐에서 불린다.
/// 관찰 대상 상태는 모두 메인 액터에서만 건드리도록 `Task { @MainActor in }` 으로 넘긴다.
@Observable
@MainActor
final class MultipeerSession {

    /// Bonjour 서비스 이름. 15자 이하, 소문자·숫자·하이픈만 쓸 수 있다.
    /// Info.plist 의 NSBonjourServices 항목과 반드시 같아야 한다.
    static let serviceType = "doodleme"

    enum Status: Equatable {
        case stopped
        case searching
        case connected(peerCount: Int)
        case failed(String)
    }

    private(set) var status: Status = .stopped
    /// 주변에서 발견된, 아직 연결되지 않은 기기.
    private(set) var nearbyPeers: [MCPeerID] = []
    private(set) var connectedPeers: [MCPeerID] = []
    /// 방금 받은 그림. 화면에서 저장한 뒤 nil 로 되돌린다.
    private(set) var received: PostTransferData?
    private(set) var lastError: String?

    /// 상대에게 보이는 내 이름.
    let displayName: String

    @ObservationIgnored private let peerID: MCPeerID
    @ObservationIgnored private let session: MCSession
    @ObservationIgnored private let delegateAdapter: DelegateAdapter
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?

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

        status = .searching
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session.disconnect()
        nearbyPeers = []
        connectedPeers = []
        status = .stopped
    }

    // MARK: - 연결

    /// 발견한 기기에게 연결을 요청한다.
    func invite(_ peer: MCPeerID) {
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 20)
    }

    // MARK: - 전송

    /// 연결된 모든 기기에 그림을 보낸다.
    func send(_ transfer: PostTransferData) {
        guard !session.connectedPeers.isEmpty else {
            lastError = "연결된 기기가 없어요."
            return
        }
        do {
            try session.send(try transfer.encoded(), toPeers: session.connectedPeers, with: .reliable)
            lastError = nil
        } catch {
            lastError = "보내기에 실패했어요: \(error.localizedDescription)"
        }
    }

    /// 화면에서 저장을 끝낸 뒤 호출한다.
    func clearReceived() {
        received = nil
    }

    // MARK: - 델리게이트 콜백 (메인 액터로 넘어온 뒤 호출됨)

    fileprivate func handleFoundPeer(_ peer: MCPeerID) {
        guard !nearbyPeers.contains(peer), !connectedPeers.contains(peer) else { return }
        nearbyPeers.append(peer)
    }

    fileprivate func handleLostPeer(_ peer: MCPeerID) {
        nearbyPeers.removeAll { $0 == peer }
    }

    fileprivate func handleStateChange(peer: MCPeerID, state: MCSessionState) {
        switch state {
        case .connected:
            nearbyPeers.removeAll { $0 == peer }
            if !connectedPeers.contains(peer) { connectedPeers.append(peer) }
        case .connecting:
            break
        case .notConnected:
            connectedPeers.removeAll { $0 == peer }
        @unknown default:
            break
        }
        status = connectedPeers.isEmpty ? .searching : .connected(peerCount: connectedPeers.count)
    }

    fileprivate func handleReceived(_ data: Data) {
        guard let transfer = PostTransferData.decode(from: data) else {
            lastError = "받은 그림을 읽을 수 없어요."
            return
        }
        received = transfer
    }

    fileprivate func handleFailure(_ message: String) {
        lastError = message
        status = .failed(message)
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
