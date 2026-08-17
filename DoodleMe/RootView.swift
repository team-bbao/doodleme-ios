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
            Tab("list", systemImage: "square.grid.2x2", value: 0) {
                GalleryPage()
            }

            Tab("Draw", systemImage: "pencil.tip", value: 1) {
                DrawingPage(selectedTabIndex: $selectedTabIndex)
            }

        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    RootView()
        .modelContainer(LocalDataStore.makePreviewContainer())
}
