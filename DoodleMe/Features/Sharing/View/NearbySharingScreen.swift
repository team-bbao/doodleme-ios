//
//  NearbySharingScreen.swift
//  DoodleMe
//

import MultipeerConnectivity
import SwiftData
import SwiftUI

/// 가까운 친구에게 그림을 보내는 전체 화면.
///
/// 가운데에는 보낼 그림이 그려진 순서대로 되살아나며 반복 재생된다.
/// 통신은 `MultipeerSession` 이 맡고 여기서는 그리기만 한다.
struct NearbySharingScreen: View {
    let post: Post
    var onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage("userName") private var userName = ""

    @Query(filter: #Predicate<Post> { $0.isProfile }) private var profilePosts: [Post]

    @State private var session: MultipeerSession?
    @State private var savedMessage = ""
    @State private var showSavedAlert = false

    // Figma 색상 스펙 (공용 값은 Color+Doodle 참고)
    private static let primary = Color.doodlePrimary
    private static let muted = Color.doodleMuted
    private static let detail = Color.doodleDetail
    private static let background = Color(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF7 / 255)
    /// 전송 진행을 나타내는 테두리. 앱 강조색은 어두워서 눈에 띄지 않아 스펙대로 파란색을 쓴다.
    static let progressRing = Color.blue

    var body: some View {
        // Figma `iPhone 17 - 3` 세로 배치:
        // 닫기 y72 / 이름 y100 / 그림 y133(337x367) / 상태 y515. 사이 간격은 모두 15.
        ZStack(alignment: .topTrailing) {
            Self.background
                .ignoresSafeArea()

            VStack(spacing: 15) {
                nameRow

                DoodleStrokeAnimation(drawing: post.drawing)
                    .frame(width: 337, height: 367)

                status

                Spacer(minLength: 0)

                if let session, !session.peers.isEmpty {
                    peerCard(session: session)
                }
            }
            // 안전영역 아래 41 지점이 Figma 의 y100 이다.
            .padding(.top, 41)

            closeButton
                .padding(.top, 13)
                .padding(.trailing, 20)
        }
        .task {
            // 상대에게 보일 이름은 프로필 이름을 그대로 쓴다.
            let newSession = MultipeerSession(displayName: userName)
            session = newSession
            newSession.start()
        }
        .onDisappear { session?.stop() }
        .onChange(of: session?.received == nil) { _, _ in saveReceivedIfNeeded() }
        // isPresented 에 .constant 를 주면 SwiftUI 가 닫힘을 되돌려 쓸 수 없어 표시가 불안정하다.
        .alert("받았어요", isPresented: $showSavedAlert) {
            Button("확인") { }
        } message: {
            Text(savedMessage)
        }
    }

    // MARK: - 상단

    private var nameRow: some View {
        HStack(spacing: 6) {
            Text("내 이름:")
                .font(.system(size: 15, weight: .medium))
            Text(session?.displayName ?? userName)
                .font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(Self.primary)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Self.primary)
                .frame(width: 55, height: 55)
                .background(.white, in: Circle())
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        }
        .accessibilityLabel("닫기")
    }

    // MARK: - 상태 문구

    @ViewBuilder
    private var status: some View {
        let count = session?.peers.count ?? 0

        VStack(spacing: 15) {
            Text(count == 0 ? "주변 사용자를 찾는중" : "\(count)명 발견")
                .font(.system(size: 25, weight: .semibold))

            if count == 0 {
                Text("상대도 서칭중인지 확인하세요")
                    .font(.system(size: 15, weight: .medium))
            }
        }
        .foregroundStyle(Self.primary)
        .multilineTextAlignment(.center)
        .frame(width: 220)
    }

    // MARK: - 상대 목록

    private func peerCard(session: MultipeerSession) -> some View {
        VStack(spacing: 0) {
            ForEach(session.peers, id: \.self) { peer in
                peerRow(peer: peer, session: session)
                    .frame(height: 85)
            }
        }
        .frame(maxWidth: .infinity)
        .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
        .padding(.horizontal, 20)
        .transition(.move(edge: .bottom))
    }

    private func peerRow(peer: MCPeerID, session: MultipeerSession) -> some View {
        let state = session.state(for: peer)

        return HStack(spacing: 16) {
            avatar(for: peer, state: state)

            Text(peer.displayName)
                .font(.headline)
                .foregroundStyle(Self.primary)
                .lineLimit(1)

            Spacer()

            Button {
                send(to: peer, session: session)
            } label: {
                Text(buttonTitle(for: state))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(width: 85, height: 38)
                    .background(state == .idle ? Self.primary : Self.muted, in: Capsule())
            }
            .disabled(state != .idle)
        }
        .padding(.horizontal, 20)
    }

    /// 아직 상대의 진짜 프로필은 알 수 없어서 기본 그림을 골라 붙인다.
    /// 전송이 시작되면 테두리가 돌고, 끝나면 테두리가 완성된다.
    private func avatar(for peer: MCPeerID, state: MultipeerSession.TransferState) -> some View {
        Image(PeerAvatarPalette.image(for: peer.displayName))
            .resizable()
            .scaledToFill()
            .frame(width: 55, height: 55)
            .clipShape(Circle())
            .padding(3)
            .overlay {
                switch state {
                case .sending:
                    SendingRing()
                case .sent:
                    Circle().stroke(Self.progressRing, lineWidth: 2)
                default:
                    Circle().stroke(.gray.opacity(0.2), lineWidth: 1)
                }
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
        session.send(
            PostTransferData(
                post: post,
                senderName: userName,
                profileDrawingData: profilePosts.first?.drawingData
            ),
            to: peer
        )
    }

    private func saveReceivedIfNeeded() {
        guard let session, let received = session.received else { return }
        modelContext.insert(received.makePost())
        session.clearReceived()
        savedMessage = "\(received.senderName ?? Post.unknownSenderName) 님의 그림을 저장했어요."
        showSavedAlert = true
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
