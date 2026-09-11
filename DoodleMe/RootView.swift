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
            // Figma `iPhone 17 - 12` 의 `Tab Bar Buttons`(85:380) 는 갤러리를 왼쪽에 둔다.
            Tab("Tab 1", systemImage: "photo.on.rectangle.fill", value: 0) {
                GalleryPage()
                    .tint(Color.doodlePrimary)
            }

            Tab("Tab 2", systemImage: "pencil.and.scribble", value: 1) {
                DrawingPage(selectedTabIndex: $selectedTabIndex)
                    .tint(Color.doodlePrimary)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        // 고른 탭을 파랗게 둔다. Figma 의 탭바가 시스템 기본 강조색 그대로다.
        //
        // 여기에 준 색은 아래로 흘러 화면 안까지 물들인다.
        // 타이머 막대와 그리기 도구 선택기가 `Color.accentColor` 를 쓰고 있어
        // 그냥 두면 그리기 화면이 함께 파래진다.
        // 그래서 각 탭의 내용에서 앱 색(`#424242`)으로 되돌려 놓는다.
        .tint(.blue)
    }
}

#Preview {
    RootView()
        .modelContainer(LocalDataStore.makePreviewContainer())
}
