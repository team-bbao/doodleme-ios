//
//  NearbySharingPopup.swift
//  DoodleMe
//

import MultipeerConnectivity
import SwiftData
import SwiftUI

/// 가까운 기기와 그림을 주고받는 팝업의 **내용**.
///
/// 껍데기(어두운 배경 · 카드 · 애니메이션)는 `DoodlePopup` 이 맡는다.
/// 여기는 안쪽만 그리므로, 디자인을 바꿀 때는 이 파일만 손보면 된다.
/// 통신 로직은 `MultipeerSession` 에 있어서 화면을 갈아엎어도 그대로 쓸 수 있다.
///
/// 보내는 쪽에서 여는 팝업이지만, 열려 있는 동안 상대가 보낸 그림도 함께 받는다.
struct NearbySharingPopup: View {
    let post: Post
    var onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage("userName") private var userName = ""

    @Query(filter: #Predicate<Post> { $0.isProfile }) private var profilePosts: [Post]

    @State private var session: MultipeerSession?
    @State private var savedMessage: String?
    @State private var sentPeerNames: Set<String> = []

    var body: some View {
        VStack(spacing: 16) {
            Text("가까운 친구에게 보내기")
                .font(.headline)

            if let session {
                statusLine(session)
                peerList(session)

                if let savedMessage {
                    Text(savedMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if let error = session.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            } else {
                ProgressView()
                    .padding(.vertical, 24)
            }

            Button("닫기") { onClose() }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.timeColor1.opacity(0.6), in: RoundedRectangle(cornerRadius: 30))
                .foregroundStyle(.black)
                .padding(.top, 4)
        }
        .task {
            // 상대에게 보일 이름은 프로필 이름을 그대로 쓴다.
            let newSession = MultipeerSession(displayName: userName)
            session = newSession
            newSession.start()
        }
        .onDisappear {
            session?.stop()
        }
        .onChange(of: session?.received == nil) { _, _ in
            saveReceivedIfNeeded()
        }
    }

    // MARK: - 조각들

    @ViewBuilder
    private func statusLine(_ session: MultipeerSession) -> some View {
        VStack(spacing: 4) {
            Text(statusText(session.status))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("상대도 이 화면을 열어야 서로를 찾아요")
                .font(.caption)
                .foregroundStyle(.secondary)
                .opacity(0.7)
        }
    }

    @ViewBuilder
    private func peerList(_ session: MultipeerSession) -> some View {
        VStack(spacing: 8) {
            ForEach(session.connectedPeers, id: \.self) { peer in
                peerRow(name: peer.displayName, systemImage: "person.fill.checkmark") {
                    if sentPeerNames.contains(peer.displayName) {
                        Text("보냄")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("보내기") { send(from: session, to: peer) }
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.accentColor, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
            }

            ForEach(session.nearbyPeers, id: \.self) { peer in
                peerRow(name: peer.displayName, systemImage: "antenna.radiowaves.left.and.right") {
                    Button("연결") { session.invite(peer) }
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.gray.opacity(0.15), in: Capsule())
                }
            }

            if session.connectedPeers.isEmpty && session.nearbyPeers.isEmpty {
                Text("주변을 찾는 중…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private func peerRow<Trailing: View>(
        name: String,
        systemImage: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(name)
                .lineLimit(1)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private func statusText(_ status: MultipeerSession.Status) -> String {
        switch status {
        case .stopped: "중지됨"
        case .searching: "주변을 찾는 중"
        case .connected(let count): "\(count)명과 연결됨"
        case .failed(let message): message
        }
    }

    // MARK: - 동작

    private func send(from session: MultipeerSession, to peer: MCPeerID) {
        session.send(
            PostTransferData(
                post: post,
                senderName: userName,
                profileDrawingData: profilePosts.first?.drawingData
            )
        )
        sentPeerNames.insert(peer.displayName)
    }

    private func saveReceivedIfNeeded() {
        guard let session, let received = session.received else { return }
        modelContext.insert(received.makePost())
        session.clearReceived()
        savedMessage = "\(received.senderName ?? Post.unknownSenderName) 님의 그림을 저장했어요."
    }
}
