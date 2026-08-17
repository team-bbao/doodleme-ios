//
//  RootView.swift
//  DoodleMe
//

import SwiftUI
import SwiftData

/// 앱의 최상위 뷰. 탭 화면을 띄우고 `doodleme://` 딥링크 수신을 처리한다.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var importSuccess = false

    var body: some View {
        MainTabView()
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

/// 갤러리 / 그리기 탭 구성.
struct MainTabView: View {
    @State private var selectedTabIndex = 0

    var body: some View {
        TabView(selection: $selectedTabIndex) {
            Tab("list", systemImage: "square.grid.2x2", value: 0) {
                GalleryPage()
            }

            Tab("Draw", systemImage: "pencil.tip", value: 1) {
                DrawingPage(selectedTabIndex: $selectedTabIndex)
            }

        //    Tab("Scan", systemImage: "qrcode.viewfinder", value: 2) {
        //        QRScannerView()
        //    }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    RootView()
        .modelContainer(LocalDataStore.makePreviewContainer())
}
