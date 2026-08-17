//
//  NearbySharingView.swift
//  DoodleMe
//

import MultipeerConnectivity
import SwiftData
import SwiftUI

/// 가까운 기기와 그림을 주고받는 화면.
///
/// `post` 가 있으면 보내기 겸 받기, `nil` 이면 받기 전용으로 동작한다.
/// 디자인은 아직 임시다 — 기능 확인용 최소 UI.
struct NearbySharingView: View {
    /// 보낼 그림. 받기 전용으로 열면 nil.
    var post: Post?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName = ""

    @Query(filter: #Predicate<Post> { $0.isProfile }) private var profilePosts: [Post]

    @State private var session: MultipeerSession?
    @State private var savedMessage: String?
    @State private var sentPeerNames: Set<String> = []

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    content(session: session)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(post == nil ? "그림 받기" : "가까운 친구에게 보내기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .task {
            // 상대에게 보일 이름은 프로필 이름을 쓴다.
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
        .alert("받았어요", isPresented: .constant(savedMessage != nil)) {
            Button("확인") { savedMessage = nil }
        } message: {
            Text(savedMessage ?? "")
        }
    }

    @ViewBuilder
    private func content(session: MultipeerSession) -> some View {
        List {
            Section {
                LabeledContent("내 이름", value: session.displayName)
                LabeledContent("상태", value: statusText(session.status))
            } footer: {
                Text("두 사람이 이 화면을 함께 열어두면 서로를 찾습니다. 같은 Wi-Fi 가 아니어도 됩니다.")
            }

            if !session.connectedPeers.isEmpty {
                Section("연결됨") {
                    ForEach(session.connectedPeers, id: \.self) { peer in
                        HStack {
                            Label(peer.displayName, systemImage: "person.fill.checkmark")
                            Spacer()
                            if post != nil {
                                if sentPeerNames.contains(peer.displayName) {
                                    Text("보냄")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Button("보내기") { send(from: session, to: peer) }
                                        .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                    }
                }
            }

            Section("주변 기기") {
                if session.nearbyPeers.isEmpty {
                    Text("찾는 중…")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(session.nearbyPeers, id: \.self) { peer in
                        Button {
                            session.invite(peer)
                        } label: {
                            Label(peer.displayName, systemImage: "antenna.radiowaves.left.and.right")
                        }
                    }
                }
            }

            if let error = session.lastError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func statusText(_ status: MultipeerSession.Status) -> String {
        switch status {
        case .stopped: "중지됨"
        case .searching: "주변을 찾는 중"
        case .connected(let count): "\(count)명과 연결됨"
        case .failed(let message): message
        }
    }

    private func send(from session: MultipeerSession, to peer: MCPeerID) {
        guard let post else { return }
        let transfer = PostTransferData(
            post: post,
            senderName: userName,
            profileDrawingData: profilePosts.first?.drawingData
        )
        session.send(transfer)
        sentPeerNames.insert(peer.displayName)
    }

    private func saveReceivedIfNeeded() {
        guard let session, let received = session.received else { return }
        modelContext.insert(received.makePost())
        session.clearReceived()
        savedMessage = "\(received.senderName ?? Post.unknownSenderName) 님의 그림을 저장했어요."
    }
}
