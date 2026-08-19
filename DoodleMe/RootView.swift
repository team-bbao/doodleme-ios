//
//  RootView.swift
//  DoodleMe
//

import SwiftData
import SwiftUI

/// 앱의 최상위 뷰.
struct RootView: View {
    var body: some View {
        MainTabView()
    }
}

/// 갤러리 / 그리기 탭 구성.
struct MainTabView: View {
    @State private var selectedTabIndex = 0

    var body: some View {
        TabView(selection: $selectedTabIndex) {
            // 자리만 바꾼다. value 는 그대로 두어야 저장 후 갤러리로 돌아가는 코드가 계속 맞는다.
            Tab("그리기", systemImage: "pencil.tip", value: 1) {
                DrawingPage(selectedTabIndex: $selectedTabIndex)
            }

            Tab("갤러리", systemImage: "square.grid.2x2", value: 0) {
                GalleryPage()
            }

        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    RootView()
        .modelContainer(LocalDataStore.makePreviewContainer())
}
