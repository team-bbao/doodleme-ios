//
//  NearbySharingScreen.swift
//  DoodleMe
//

import CoreGraphics
import MultipeerConnectivity
import PencilKit
import SwiftData
import SwiftUI
import UIKit

/// 가까운 친구에게 그림을 보내는 전체 화면.
///
/// 가운데에는 보낼 그림이 그려진 순서대로 되살아나며 반복 재생된다.
/// 통신은 `MultipeerSession` 이 맡고 여기서는 그리기만 한다.
///
/// `post` 가 없으면 받기 전용이다. 보낼 그림이 없으니 전송 버튼도 뜨지 않고,
/// 상대가 보내주는 그림을 받기만 한다.
struct NearbySharingScreen: View {
    var post: Post?
    var onClose: () -> Void

    /// 그림을 받아 저장한 직후. 받은 그림을 들고 부른다.
    /// 갤러리가 이걸 받아 그 메모지가 있는 자리를 보여준다.
    var onReceived: ((Post) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @AppStorage("userName") private var userName = ""
    /// 받은 그림이 쌓이는 섹션을 갤러리가 열도록 적어 둔다.
    @AppStorage(GallerySection.storageKey) private var gallerySection = GallerySection.receivedFromOthers.rawValue

    @Query(filter: #Predicate<Post> { $0.isProfile }) private var profilePosts: [Post]

    @State private var session: MultipeerSession?
    /// 가운데에서 되살릴 획. 원본이 바뀔 때만 다시 푼다.
    @State private var animatedStrokes: [[CGPoint]] = DefaultDoodle.strokes

    // Figma 색상 스펙 (공용 값은 Color+Doodle 참고)
    private static let primary = Color.doodlePrimary
    private static let muted = Color.doodleMuted
    /// 전송 진행을 나타내는 테두리. 앱 강조색은 어두워서 눈에 띄지 않아 스펙대로 파란색을 쓴다.
    static let progressRing = Color.blue

    /// 버튼 높이. 앱 전체가 같은 값을 쓴다.
    private static let buttonHeight = DoodleMetrics.buttonSide

    var body: some View {
        // Figma `iPhone 17 - 9` 세로 배치:
        // 닫기 y72 / 이름 y100 / 그림 y133(337x367) / 상태 y539 / 다시 찾기 y729.
        ZStack {
            // Figma `iPhone 17 - 3` 의 바탕.
            // 종이 질감 레이어(`배경 1`)는 디자인에서 hidden 으로 꺼졌다.
            Color.doodleBackground
                .ignoresSafeArea()

            VStack(spacing: 15) {
                nameRow

                // 못 찾고 끝났으면 그리기도 멈춘다. 계속 움직이면 아직 찾는 중처럼 보인다.
                DoodleStrokeAnimation(
                    strokes: animatedStrokes,
                    isAnimating: session?.searchTimedOut != true
                )
                // 자리를 꽉 채우면 그림이 답답하고 가장자리 획이 잘려 보인다.
                // 보낼 그림이든 기본 낙서든 같은 여백을 둔다.
                .padding(30)
                .frame(width: 337, height: 367)

                status

                Spacer(minLength: 0)

                if session?.searchTimedOut == true || session?.localNetworkBlocked == true {
                    VStack(spacing: 8) {
                        retryButton
                        settingsButton
                    }
                    // 안전영역 안쪽 기준. Figma 의 화면 아래 75 에서 홈 인디케이터 몫을 뺀 값이다.
                    .padding(.bottom, 24)
                } else if let session, !session.peers.isEmpty {
                    peerCard(session: session)
                }
            }
            // 화면 폭을 다 쓰게 해야 안쪽 요소가 가운데로 온다.
            .frame(maxWidth: .infinity)
            // 안전영역 아래 41 지점이 Figma 의 y100 이다.
            .padding(.top, 41)

            // ZStack 정렬을 topTrailing 으로 주면 본문까지 딸려 가므로
            // 닫기 버튼 자신만 모서리로 보낸다.
            closeButton
                .padding(.top, 13)
                .padding(.trailing, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .task {
            // 상대에게 보일 이름은 프로필 이름을 그대로 쓴다.
            let newSession = MultipeerSession(displayName: userName)
            session = newSession
            newSession.start()
        }
        .task(id: animatedSourceData) {
            animatedStrokes = Self.strokes(from: animatedSourceData)
        }
        .onDisappear { session?.stop() }
        // 받은 횟수만 지켜본다. 그림 값을 비교하면 같은 그림이 두 번 왔을 때 놓친다.
        .onChange(of: session?.receivedCount) { _, _ in saveReceivedIfNeeded() }
    }

    /// 가운데에서 되살릴 그림의 원본 바이너리.
    ///
    /// 보낼 그림 → 내 프로필 그림 순으로 찾는다.
    /// 받기 전용으로 열면 보낼 그림이 없으므로 내 프로필이 그려진다.
    /// 둘 다 없으면 `nil` 을 돌려주고 `DefaultDoodle` 이 대신 그려진다.
    ///
    /// 여기서는 바이너리만 고른다. 푸는 건 `.task` 가 한 번만 한다.
    private var animatedSourceData: Data? {
        for candidate in [post?.drawingData, profilePosts.first?.drawingData] {
            if let candidate, !candidate.isEmpty { return candidate }
        }
        return nil
    }

    /// 그림을 점열로 푸는 일은 비싸다.
    ///
    /// 예전에는 `body` 안에서 `PKDrawing` 을 디코드하고 모든 획을 다시 풀었다.
    /// `body` 는 상대를 하나 찾을 때마다, 전송 상태가 바뀔 때마다 다시 도는데
    /// 그때마다 같은 계산을 처음부터 되풀이했다.
    /// 이제 원본이 바뀔 때만 한 번 풀어 여기에 담아 둔다.
    private static func strokes(from data: Data?) -> [[CGPoint]] {
        guard let data else { return DefaultDoodle.strokes }

        let drawing = PKDrawing(doodleData: data)
        guard !drawing.strokes.isEmpty else { return DefaultDoodle.strokes }
        return drawing.pointStrokes
    }

    // MARK: - 상단

    private var nameRow: some View {
        // 한 줄이 라벨과 값으로 갈려 보이지 않도록 굵기를 맞춘다.
        // Figma 17-3 은 라벨을 Medium 으로 두지만, 화면에서는 두 조각처럼 읽혔다.
        HStack(spacing: 6) {
            Text("내 이름:")
                .font(.system(size: 15, weight: .semibold))
            Text(session?.displayName ?? Post.unknownSenderName)
                .font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(Self.primary)
    }

    /// Figma `iPhone 17 - 9` 의 `Frame 6`: 우상단 X.
    /// Figma 원본은 55 지만 앱의 버튼 규격에 맞춰 44 로 쓴다.
    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Self.primary)
                .frame(width: Self.buttonHeight, height: Self.buttonHeight)
                .background(.white, in: Circle())
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        }
        .accessibilityLabel("닫기")
    }

    // MARK: - 상태 문구

    @ViewBuilder
    private var status: some View {
        let count = session?.peers.count ?? 0

        let timedOut = session?.searchTimedOut ?? false
        let blocked = session?.localNetworkBlocked ?? false

        // Figma `iPhone 17 - 9` 의 `Frame 20`: 제목과 안내 사이 22, 가운데 정렬.
        VStack(spacing: 22) {
            Text(statusTitle(count: count, timedOut: timedOut || blocked))
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(Self.primary)
                // 디자인에서 제목은 한 줄이다(`whitespace-nowrap`, 폭 292).
                // 폭을 좁게 잡으면 제멋대로 접히므로 줄바꿈 자체를 막는다.
                .fixedSize(horizontal: true, vertical: false)

            if count == 0 {
                // Figma: SF Pro Medium 15 / 행높이 20 / `#6A6A6A`.
                // 15pt 기본 행높이가 약 18 이라 2 를 더하면 20 에 맞는다.
                Text(statusDetail(timedOut: timedOut, blocked: blocked))
                    .font(.system(size: 15, weight: .medium))
                    .lineSpacing(2)
                    .foregroundStyle(Color.doodleSubtext)
            }

            // 조용히 실패하면 무엇이 잘못됐는지 알 길이 없다.
            // 디자인에 없는 요소라 안내와 같은 간격에 얹어 둔다.
            if let lastError = session?.lastError {
                Text(lastError)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.red)
            }
        }
        .multilineTextAlignment(.center)
        // 안내의 첫 줄("기기가 가까이 있는지, 로컬 네트워크 권한이")이 약 310 이라
        // 320 으로는 아슬아슬해 제멋대로 접혔다. 넉넉히 열어 정한 자리에서만 끊기게 한다.
        .frame(maxWidth: 360)
        // Figma 는 그림 아래 39 를 띄운다. 바깥 VStack 이 이미 15 를 주므로 나머지만 더한다.
        .padding(.top, 24)
    }

    /// 다시 찾기 버튼. Figma `iPhone 17 - 9` 의 `Frame 21` 자리에 168x48 로 놓는다.
    ///
    /// Figma 원본은 흰 알약에 파란 글씨지만, 이 앱에서 파란색은 여기 하나뿐이라 튀었다.
    /// 지금은 앱의 기본 동작 버튼과 같은 먹색 채움을 쓴다.
    /// `iPhone 17 - 16` 의 「예」 버튼과 같은 결이다.
    private var retryButton: some View {
        Button {
            session?.searchAgain()
        } label: {
            Text("다시 찾기")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 168, height: 48)
                .background(Self.primary, in: Capsule())
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .transition(.opacity)
    }

    /// 로컬 네트워크 권한은 앱에서 켤 수 없다. 설정 앱의 이 앱 화면으로 데려다주는 것이 최선이다.
    ///
    /// `openSettingsURLString` 은 설정 앱의 **이 앱 화면**을 연다.
    /// 거기에 「로컬 네트워크」 스위치가 있어 한 번 더 헤맬 필요가 없다.
    ///
    /// 다시 찾기보다 한 단계 낮은 선택지라 배경 없이 글자만 두고 색도 한 톤 흐리게 쓴다.
    private var settingsButton: some View {
        Button {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        } label: {
            Text("설정 열기")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.doodleSubtext)
                .frame(height: Self.buttonHeight)
                .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
        .transition(.opacity)
    }

    /// 제목은 언제나 한 줄이다. Figma `iPhone 17 - 9` 기준.
    private func statusTitle(count: Int, timedOut: Bool) -> String {
        if count > 0 { return "\(count)명 발견" }
        return timedOut ? "주변 사용자를 찾지 못했어요" : "주변 사용자를 찾는중"
    }

    /// 못 찾은 이유를 짚어 준다.
    ///
    /// 권한이 막혔는지 그냥 아무도 없는지는 사용자가 알 길이 없다.
    /// 막힌 게 확인되면 그것부터 말해 주고, 아니면 흔한 원인을 짚어 준다.
    ///
    /// 줄바꿈을 글자 수에 맡기지 않고 직접 넣는다.
    /// 맡겨두면 "로컬 / 네트워크" 처럼 한 낱말이 두 줄로 갈려 읽다가 걸린다.
    ///
    /// Figma 의 안내("기기가 가까이 있는지 확인한 후 / 다시 시도해 주세요.")는 두 줄이다.
    /// 로컬 네트워크 권한 안내는 디자인이 그려지기 전에 덧붙인 문구라 원문에는 없지만,
    /// 두 줄이라는 리듬은 그대로 지킨다.
    private func statusDetail(timedOut: Bool, blocked: Bool) -> String {
        if blocked {
            return """
                로컬 네트워크 권한이 꺼져 있어요.
                설정에서 켜야 주변 기기를 찾을 수 있어요.
                """
        }
        if timedOut {
            return """
                기기가 가까이 있는지, 로컬 네트워크 권한이
                켜져 있는지 확인해주세요
                """
        }
        return "상대도 서칭중인지 확인하세요"
    }

    // MARK: - 상대 목록

    /// 상대 한 명이 차지하는 높이.
    private static let peerRowHeight: CGFloat = 85
    /// 스크롤 없이 한 번에 보여줄 사람 수. 그보다 많으면 목록만 스크롤한다.
    private static let visiblePeerLimit = 3

    private func peerCard(session: MultipeerSession) -> some View {
        // 카드가 화면 밖으로 넘어가지 않게 높이를 사람 수에 맞춘다.
        // 예전에는 Figma 대로 아래를 잘라 뒀는데, 4명째부터는 화면 밖이라
        // 스크롤도 안 되고 보낼 방법이 없었다.
        let rows = min(session.peers.count, Self.visiblePeerLimit)

        return ScrollView {
            VStack(spacing: 0) {
                ForEach(session.peers, id: \.self) { peer in
                    peerRow(peer: peer, session: session)
                        .frame(height: Self.peerRowHeight)
                }
            }
        }
        .frame(height: Self.peerRowHeight * CGFloat(rows))
        // 목록이 다 들어오면 튕기지 않게 한다. 스크롤될 때만 튕긴다.
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 30)
                .fill(.white)
                .shadow(color: .black.opacity(0.12), radius: 16, y: -2)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .transition(.move(edge: .bottom))
    }

    private func peerRow(peer: MCPeerID, session: MultipeerSession) -> some View {
        let state = session.state(for: peer)

        return HStack(spacing: 16) {
            avatar(for: peer, state: state)

            Text(peer.displayName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Self.primary)
                .lineLimit(1)

            Spacer()

            // 받기 전용으로 열었으면 보낼 그림이 없으므로 버튼을 띄우지 않는다.
            if post != nil {
                Button {
                    send(to: peer, session: session)
                } label: {
                    Text(buttonTitle(for: state))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.doodleOnPrimary)
                        .frame(width: 83, height: Self.buttonHeight)
                        .background(
                            canSend(in: state) ? Self.primary : Self.muted,
                            in: RoundedRectangle(cornerRadius: 30)
                        )
                }
                // 실패했으면 다시 눌러야 한다. 예전에는 idle 만 허용해서
                // "재시도" 라고 써 놓고 정작 눌리지 않았다.
                .disabled(!canSend(in: state))
            }
        }
        .padding(.horizontal, 22)
    }

    /// 아직 상대의 진짜 프로필은 알 수 없어서 기본 그림을 골라 붙인다.
    /// 전송이 시작되면 테두리가 돌고, 끝나면 테두리가 완성된다.
    private func avatar(for peer: MCPeerID, state: MultipeerSession.TransferState) -> some View {
        ZStack {
            Circle().fill(.white)

            Image(PeerAvatarPalette.image(for: peer.displayName))
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        }
        .frame(width: 46, height: 46)
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        .overlay {
            switch state {
            case .sending:
                SendingRing()
            case .sent:
                Circle().stroke(Self.progressRing, lineWidth: 2)
            default:
                Circle().stroke(Color.doodleHairline, lineWidth: 1)
            }
        }
    }

    /// 지금 보낼 수 있는 상태인가. 보내는 중이거나 이미 보냈으면 막는다.
    private func canSend(in state: MultipeerSession.TransferState) -> Bool {
        switch state {
        case .idle, .failed: true
        case .sending, .sent: false
        }
    }

    private func buttonTitle(for state: MultipeerSession.TransferState) -> String {
        switch state {
        case .idle: "전송"
        case .sending: "전송중"
        case .sent: "전송됨"
        case .failed: "재시도"
        }
    }

    // MARK: - 동작

    private func send(to peer: MCPeerID, session: MultipeerSession) {
        guard let post else { return }
        session.send(
            PostTransferData(
                post: post,
                // 이름을 비워 둔 사람도 상대 화면에는 이름이 있어야 한다.
                // 세션이 이미 「doodle.me 사용자」로 채워 둔 값을 그대로 쓴다.
                senderName: session.displayName,
                profileDrawingData: profilePosts.first?.drawingData
            ),
            to: peer
        )
    }

    /// 그림이 도착하면 저장하고 이 화면을 접는다.
    ///
    /// 예전에는 "받았어요" 알림만 띄우고 이 화면에 그대로 머물렀다.
    /// 받으러 온 사람의 볼일은 거기서 끝나는데 나가는 건 직접 해야 했고,
    /// 나가서도 받은 그림이 어디에 쌓였는지 스스로 찾아야 했다.
    ///
    /// 이제 갤러리로 돌려보내며 「너가 그린」을 펴고 그 메모지 자리까지 보여준다.
    /// 받았다는 말은 따로 하지 않는다 — 그림이 눈앞에 있는 것이 그 말이다.
    private func saveReceivedIfNeeded() {
        guard let session, let received = session.received else { return }

        let saved = received.makePost()
        modelContext.insert(saved)
        // 저장을 미루면 화면을 닫는 사이에 사라질 수 있다. 받은 즉시 디스크에 남긴다.
        try? modelContext.save()
        session.clearReceived()

        // 받은 그림은 "너가 그린" 에 쌓인다.
        gallerySection = GallerySection.receivedFromOthers.rawValue

        onReceived?(saved)
        onClose()
    }
}

/// 전송 중임을 알리는 도는 테두리.
///
/// `withAnimation(...repeatForever)` 대신 `TimelineView` 로 매 프레임 각도를 직접 구한다.
/// 목록이 다시 그려져도 회전이 끊기거나 어긋나지 않는다.
private struct SendingRing: View {
    var body: some View {
        TimelineView(.animation) { context in
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(NearbySharingScreen.progressRing, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(context.date.timeIntervalSinceReferenceDate * 240))
        }
    }
}
