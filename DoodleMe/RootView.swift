//
//  RootView.swift
//  DoodleMe
//

import SwiftData
import SwiftUI

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

    private func handleImport(url: URL) {
        // 파싱·검증·변환은 모두 PostTransferData가 맡는다. QR 스캔도 같은 경로를 쓴다.
        guard let transferData = PostTransferData.decode(deepLink: url) else { return }
        modelContext.insert(transferData.makePost())
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
