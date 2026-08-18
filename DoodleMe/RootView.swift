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
            // 아이콘만 둔다. 글자는 빼되 접근성 라벨은 남긴다.
            Tab(value: 0) {
                GalleryPage()
            } label: {
                Image(systemName: "square.grid.2x2")
                    .accessibilityLabel("갤러리")
            }

            Tab(value: 1) {
                DrawingPage(selectedTabIndex: $selectedTabIndex)
            } label: {
                Image(systemName: "pencil.tip")
                    .accessibilityLabel("드로잉")
            }

        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    RootView()
        .modelContainer(LocalDataStore.makePreviewContainer())
}
