import SwiftUI
import SwiftData

@main
struct DuddlemeApp: App {
    var body: some Scene {
        WindowGroup {
            DeepLinkHandler()
        }
        .modelContainer(for: Post.self)
    }
}

struct DeepLinkHandler: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPosts: [Post]
    @State private var importSuccess = false

    var body: some View {
        Viewpage()
            .onOpenURL { url in
                handleImport(url: url)
            }
            .alert("저장 완료", isPresented: $importSuccess) {
                Button("확인") { }
            } message: {
                Text("상대방의 그림이 By others에 저장됐어요.")
            }
    }

    func handleImport(url: URL) {
        guard url.scheme == "duddleme",
              url.host == "import",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let dataParam = components.queryItems?.first(where: { $0.name == "data" })?.value
        else { return }

        // base64url → base64 표준 형식 복원
        var base64 = dataParam
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padCount = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: padCount)

        guard let jsonData = Data(base64Encoded: base64),
              let json = String(data: jsonData, encoding: .utf8),
              let transferData = PostTransferData.decode(from: json)
        else { return }

        let newPost = Post(lines: transferData.makeDrawingLines(), text: transferData.t, isMine: false)
        newPost.createdAt = Date(timeIntervalSince1970: transferData.dt)
        newPost.senderName = transferData.n ?? "홍길동"
        newPost.senderProfileLines = transferData.makeProfileLines() ?? []
        modelContext.insert(newPost)

        importSuccess = true
    }
}
