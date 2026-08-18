//
//  NearbySharingScreen.swift
//  DoodleMe
//

import CoreGraphics
import MultipeerConnectivity
import PencilKit
import SwiftData
import SwiftUI

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
        ZStack {
            Self.background
                .ignoresSafeArea()

            VStack(spacing: 15) {
                nameRow

                Group {
                    if let animatedDrawing {
                        DoodleStrokeAnimation(drawing: animatedDrawing)
                    } else {
                        DoodleStrokeAnimation(strokes: DefaultDoodle.strokes)
                    }
                }
                // 자리를 꽉 채우면 그림이 답답하고 가장자리 획이 잘려 보인다.
                // 보낼 그림이든 기본 낙서든 같은 여백을 둔다.
                .padding(30)
                .frame(width: 337, height: 367)

                status

                Spacer(minLength: 0)

                if let session, !session.peers.isEmpty {
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
        .onDisappear { session?.stop() }
        .onChange(of: session?.received == nil) { _, _ in saveReceivedIfNeeded() }
        // isPresented 에 .constant 를 주면 SwiftUI 가 닫힘을 되돌려 쓸 수 없어 표시가 불안정하다.
        .alert("받았어요", isPresented: $showSavedAlert) {
            Button("확인") { }
        } message: {
            Text(savedMessage)
        }
    }

    /// 가운데에서 되살릴 그림.
    ///
    /// 받기 전용으로 열면 보낼 그림이 없어 가운데가 비어 버린다.
    /// 그럴 때는 `DefaultDoodle` 이 대신 그려진다. (`nil` 을 돌려주는 경우)
    ///
    /// 내 프로필 그림으로 채우지 않는 이유는, 그러면 사람마다 다른 그림이 떠서
    /// "보내는 그림을 보여주는 자리" 라는 뜻이 흐려지기 때문이다.
    private var animatedDrawing: PKDrawing? {
        guard let candidate = post?.drawing, !candidate.strokes.isEmpty else { return nil }
        return candidate
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
        // Figma 카드는 높이 361 이고 화면 아래로 잘려 나간다. 행(85x3)만으로는 모자라 여백을 더한다.
        .padding(.bottom, 106)
        .background {
            RoundedRectangle(cornerRadius: 30)
                .fill(.white)
                .shadow(color: .black.opacity(0.12), radius: 16, y: -2)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, -60)
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
                        .frame(width: 83, height: 39)
                        .background(
                            state == .idle ? Self.primary : Self.muted,
                            in: RoundedRectangle(cornerRadius: 30)
                        )
                }
                .disabled(state != .idle)
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
