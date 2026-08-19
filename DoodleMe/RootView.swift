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
    /// 각 화면이 탭바를 내려달라고 했는지.
    /// 그리기는 그리는 동안, 갤러리는 그림을 펼쳐 볼 때 비켜준다.
    @State private var drawingWantsTabBar = true
    @State private var galleryWantsTabBar = true

    /// 지금 보고 있는 화면이 하라는 대로 한다.
    /// 두 화면이 한 변수를 나눠 쓰면 늦게 쓴 쪽이 이겨 버려서, 따로 듣는다.
    private var showsTabBar: Bool {
        selectedTabIndex == 1 ? drawingWantsTabBar : galleryWantsTabBar
    }

    var body: some View {
        TabView(selection: $selectedTabIndex) {
            // 자리만 바꾼다. value 는 그대로 두어야 저장 후 갤러리로 돌아가는 코드가 계속 맞는다.
            Tab("그리기", systemImage: "pencil.tip", value: 1) {
                DrawingPage(selectedTabIndex: $selectedTabIndex, showsTabBar: $drawingWantsTabBar)
            }

            Tab("갤러리", systemImage: "square.grid.2x2", value: 0) {
                GalleryPage(showsTabBar: $galleryWantsTabBar)
            }

        }
        .tabViewStyle(.sidebarAdaptable)
        // 기본 탭바는 선택 알약을 스스로 그리고 색을 열어주지 않는다.
        // appearance 로 알약 색·이미지를 모두 시도했지만 iOS 26 유리 탭바는 무시했다.
        // 그래서 기본 탭바를 접고 같은 모양을 직접 그린다.
        .toolbarVisibility(.hidden, for: .tabBar)
        .overlay(alignment: .bottom) {
            if showsTabBar {
                DoodleTabBar(selection: $selectedTabIndex)
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.25), value: showsTabBar)
    }
}

/// 직접 그린 탭바.
///
/// 선택된 쪽은 진한 알약을 깔고 글씨·심볼이 흰색으로 뒤집힌다.
/// 저장 버튼과 확인창의 주 버튼이 쓰는 어법을 그대로 가져왔다.
private struct DoodleTabBar: View {
    @Binding var selection: Int

    private struct Item: Identifiable {
        let title: String
        let symbol: String
        let value: Int
        var id: Int { value }
    }

    private let items = [
        Item(title: "그리기", symbol: "pencil.tip", value: 1),
        Item(title: "갤러리", symbol: "square.grid.2x2", value: 0),
    ]

    /// 탭 한 칸의 높이. 알약이 손끝에 넉넉히 잡히도록 잡았다.
    private static let itemHeight: CGFloat = 58

    var body: some View {
        // 알약과 바깥 막대가 같은 유리로 묶이도록 한 그릇에 담는다.
        // 따로 두면 두 유리가 서로를 굴절시켜 겹치는 자리가 탁해진다.
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(items) { item in
                    let isSelected = selection == item.value

                    Button {
                        selection = item.value
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 20))
                            Text(item.title)
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                        .frame(width: 96, height: Self.itemHeight)
                        .background {
                            if isSelected {
                                // 유리에 색을 입히면 뒤가 비쳐 글씨 대비가 흔들린다.
                                // 단색을 깔고 그 위에 유리를 얹어 흰 글씨를 지킨다.
                                Capsule().fill(Color.doodlePrimary)
                                    .glassEffect(.regular.tint(Color.doodlePrimary), in: .capsule)
                            }
                        }
                        .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(4)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .padding(.bottom, 8)
        .animation(.snappy(duration: 0.25), value: selection)
    }
}

#Preview {
    RootView()
        .modelContainer(LocalDataStore.makePreviewContainer())
}
