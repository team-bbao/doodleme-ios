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

/// 갤러리 / 그리기 길잡이.
///
/// 화면 폭에 따라 **구성 자체가 다르다.**
///
/// 좁은 화면(아이폰)은 탭 바다. 애플 HIG 「Split views」 —
/// *Prefer using a split view in a regular — not a compact — environment.*
///
/// 넓은 화면(아이패드)은 사이드바다. `TabView(.sidebarAdaptable)` 을 쓰던 때에는
/// 사이드바가 본문을 **덮었고**, 코드로 접을 수도 없었다 — 그 스타일이 내주는 것은
/// `selection` 과 머리말·꼬리말뿐이라 여닫음을 다룰 손잡이가 없다.
/// `NavigationSplitView` 는 `columnVisibility` 를 binding 으로 받아
/// 펼치면 본문을 밀어내고, 카드를 열 때 코드로 접을 수 있다.
struct MainTabView: View {
    @State private var selectedTabIndex = 0
    /// 갤러리가 보고 있는 묶음. 화면 안 세그먼트와 사이드바가 같은 값을 본다.
    @AppStorage(GallerySection.storageKey) private var gallerySection = GallerySection.drawnByMe.rawValue
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// 사이드바가 펼쳐져 있는지. 넓은 화면에서만 뜻이 있다.
    /// 사이드바가 펼쳐져 있는지. 넓은 화면에서만 뜻이 있다.
    ///
    /// 두 칸짜리에서는 `.all` 이 「사이드바까지 보이기」다 —
    /// `.doubleColumn` 은 세 칸(사이드바·목록·본문)용이라 여기서는 듣지 않는다.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    /// 사이드바를 펼칠 때마다 하나씩 오른다. 갤러리가 이것을 보고 상세를 닫는다.
    @State private var closeDetailSignal = 0
    /// 사이드바의 신원 덩이를 누를 때마다 하나씩 오른다. 갤러리가 프로필 고르기를 연다.
    @State private var chooseProfileSignal = 0

    /// 프로필로 앉힌 그림. 사이드바 맨 위 신원 덩이가 이것을 보여 준다.
    @Query(filter: #Predicate<Post> { $0.isProfile }) private var profilePosts: [Post]
    /// 갤러리 머리말이 쓰던 것과 같은 이름.
    @AppStorage("userName") private var userName = ""

    private var isWideLayout: Bool { horizontalSizeClass == .regular }

    /// 사이드바가 실제로 받은 폭. 사용자가 끌어 넓히면 프로필도 따라 커진다.
    @State private var sidebarWidth: CGFloat = 320

    /// 신원 원의 지름. **사이드바 폭을 따른다.**
    ///
    /// 못박아 두면 사이드바를 넓혀도 원만 작게 남아 목록 머리가 허전해진다.
    /// 폭의 0.6 이면 좌우로 손가락 두 개쯤 여백이 남아 답답하지 않다.
    /// 사이드바는 260~360 사이라 원은 156~216 이 된다.
    private var sidebarProfileDiameter: CGFloat {
        min(Self.sidebarProfileMax, max(Self.sidebarProfileMin, sidebarWidth * 0.6))
    }

    /// 뱃지와 이름이 원과 같은 비율로 자라게 하는 값. 아이폰의 97 짜리 원을 1 로 본다.
    private var sidebarBadgeScale: CGFloat { sidebarProfileDiameter / 97 }

    private static let sidebarProfileMin: CGFloat = 140
    private static let sidebarProfileMax: CGFloat = 216
    private static let sidebarProfileSpacing: CGFloat = 12
    private static let sidebarProfilePadding: CGFloat = 18

    /// 사이드바 목록이 쓰는 고른 줄. `List` 는 고르지 않은 상태를 나타내려고 옵셔널을 받는다.
    /// 이 앱에는 「아무것도 안 고름」이 없으므로 nil 이 오면 그대로 둔다.
    private var sidebarSelection: Binding<Int?> {
        Binding(get: { selectedTabIndex },
                set: { if let value = $0 { selectedTabIndex = value } })
    }

    var body: some View {
        if isWideLayout {
            sidebarLayout
        } else {
            tabLayout
        }
    }

    // MARK: - 좁은 화면: 탭 바

    private var tabLayout: some View {
        TabView(selection: $selectedTabIndex) {
            // 자리만 바꾼다. value 는 그대로 두어야 저장 후 갤러리로 돌아가는 코드가 계속 맞는다.
            // Figma `iPhone 17 - 12` 의 `Tab Bar Buttons`(85:380) 는 갤러리를 왼쪽에 둔다.
            Tab("갤러리", systemImage: "photo.on.rectangle.fill", value: 0) {
                GalleryPage()
                    .tint(Color.doodlePrimary)
            }

            Tab("그리기", systemImage: "pencil.and.scribble", value: 1) {
                DrawingPage(selectedTabIndex: $selectedTabIndex)
                    .tint(Color.doodlePrimary)
            }
        }
        // 고른 탭을 파랗게 둔다. Figma 의 탭바가 시스템 기본 강조색 그대로다.
        //
        // 여기에 준 색은 아래로 흘러 화면 안까지 물들인다.
        // 타이머 막대와 그리기 도구 선택기가 `Color.accentColor` 를 쓰고 있어
        // 그냥 두면 그리기 화면이 함께 파래진다.
        // 그래서 각 탭의 내용에서 앱 색(`#424242`)으로 되돌려 놓는다.
        .tint(.blue)
    }

    // MARK: - 넓은 화면: 사이드바

    private var sidebarLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: sidebarSelection) {
                // 신원이 맨 위다. **세로로, 크게** 둔다.
                //
                // 사이드바가 320 이라 아이폰의 낯익은 덩이(원 위, 이름 아래)를 그대로 쓸 수 있다.
                // 본문 머리말에 있던 때에는 거의 흰 배경 위에 흰 원이 그림자로만 떠 있어
                // 겉돌았는데, 목록의 머리로 서면 그 자리가 신원의 자리라 어색하지 않다.
                // 그리기가 맨 위다. Figma 의 탭 순서(갤러리·그리기)와 다르지만,
                // 사이드바에서는 묶음이 딸린 갤러리가 여러 줄을 쓰므로
                // 한 줄짜리를 위에 두어야 목록이 머리·몸통으로 읽힌다.
                Label("그리기", systemImage: "pencil.and.scribble")
                    .tag(1)

                // 묶음이 사이드바의 본체다. 메일의 받은편지함·보낸편지함과 같은 자리.
                Section("갤러리") {
                    Label(GallerySection.drawnByMe.title, systemImage: "photo.on.rectangle.fill")
                        .tag(0)
                    Label(GallerySection.receivedFromOthers.title, systemImage: "tray.and.arrow.down.fill")
                        .tag(2)
                }
            }
            // 신원은 목록의 **행이 아니라 머리**로 얹는다.
            //
            // 행으로 두면 `List` 가 그 줄의 탭을 먼저 가져가, 안에 둔 이름 단추가 눌리지 않는다 —
            // 실제로 이름을 눌러도 이름 고치는 창이 열리지 않고 사이드바만 닫혔다.
            .safeAreaInset(edge: .top, spacing: 0) { sidebarProfile }
            .navigationTitle("doodle.me")
            .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 360)
            // 고른 줄을 파랗게 둔다. 탭 바를 쓰던 때와 같은 뜻이다.
            //
            // 파란색을 `NavigationSplitView` 바깥에 걸면 안 된다 — 그쪽이 두 칸에 제 색을
            // 다시 내려보내, 각 화면에서 앱 색으로 되돌려 둔 것을 덮는다.
            // 실제로 그랬더니 그리기 화면의 타이머 막대와 펜 선택이 파랗게 남았다.
            .tint(.blue)
        } detail: {
            // 색은 화면마다 건다. 탭 바를 쓰던 때와 같은 방식이다 —
            // 묶어서 한 번에 걸면 각 화면의 `NavigationStack` 안까지 닿지 않아
            // 타이머 막대와 도구 선택기가 파랗게 남았다.
            if selectedTabIndex == 1 {
                DrawingPage(selectedTabIndex: $selectedTabIndex)
                    .tint(Color.doodlePrimary)
            } else {
                GalleryPage(
                        onDetailChange: { isOpen in
                            // 카드를 열면 사이드바가 스스로 접힌다.
                            // 둘이 함께 열리면 격자가 554 까지 눌려 2열이 된다.
                            guard isOpen else { return }
                            withAnimation(.snappy) { columnVisibility = .detailOnly }
                        },
                        closeDetailSignal: closeDetailSignal,
                        isSidebarVisible: columnVisibility != .detailOnly,
                        chooseProfileSignal: chooseProfileSignal
                )
                .tint(Color.doodlePrimary)
            }
        }
        // 사이드바가 본문을 **밀어낸다.**
        //
        // 기본값(`automatic`)은 본문을 크게 두려고 `prominentDetail` 로 갈려,
        // 사이드바가 본문 위를 덮고 뒤가 흐려진다 — 가려지는 것이 생긴다.
        // `balanced` 는 두 칸이 자리를 나눠 가진다.
        .navigationSplitViewStyle(.balanced)
        // 사이드바를 다시 펼치면 열려 있던 상세를 닫는다.
        //
        // 여닫는 단추는 시스템이 네비게이션 바에 세운 것을 쓴다 — 제목 줄에 하나 더 두었더니
        // 똑같은 단추가 위아래로 둘이 되었고, 시스템 것을 숨기려 툴바를 감추자
        // 같은 바에 얹힌 공유·더보기·받기까지 함께 사라졌다.
        // 그래서 단추가 아니라 **결과**(`columnVisibility`)를 본다.
        .onChange(of: columnVisibility) { _, visibility in
            guard visibility != .detailOnly else { return }
            closeDetailSignal += 1
        }
        // 사이드바가 다시 펼쳐지면 열려 있던 상세를 닫는다.
        //
        // 여닫는 단추는 분할 뷰가 세운 것을 쓰므로 우리가 그 순간을 가로챌 수 없다.
        // 대신 **결과**(`columnVisibility`)를 본다. 사이드바와 상세는 같은 넓이를 두고 다툰다.
        .onChange(of: columnVisibility) { _, visibility in
            guard visibility != .detailOnly else { return }
            closeDetailSignal += 1
        }
        // 사이드바에서 묶음을 고르면 화면 안 세그먼트도 따라 움직인다.
        .onChange(of: selectedTabIndex) { _, index in
            switch index {
            case 0: gallerySection = GallerySection.drawnByMe.rawValue
            case 2: gallerySection = GallerySection.receivedFromOthers.rawValue
            default: break
            }
        }
        // 반대 방향. 세그먼트로 바꾸거나 그림을 받아 「나를 그린」으로 갈 때
        // 사이드바에서 짚고 있는 줄도 함께 옮겨 간다.
        .onChange(of: gallerySection) { _, value in
            guard selectedTabIndex != 1 else { return }
            selectedTabIndex = value == GallerySection.receivedFromOthers.rawValue ? 2 : 0
        }
    }

    /// 사이드바를 여닫는다. 펼칠 때는 열려 있던 상세를 닫는다 —
    /// 사이드바와 상세는 같은 넓이를 두고 다투므로 하나만 선다.

    /// 사이드바 맨 위의 신원 덩이. 세로로, 사이드바 폭에 맞춰 크게 선다.
    private var sidebarProfile: some View {
        VStack(spacing: Self.sidebarProfileSpacing) {
            // 사진을 바꾸는 문. 아이폰과 같이 **연필 뱃지가 있는 원**이 그 문이다.
            Button {
                selectedTabIndex = 0
                chooseProfileSignal += 1
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    ProfileAvatar(drawingData: profilePosts.first?.drawingData,
                                  diameter: sidebarProfileDiameter)
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 2, y: 2)

                    // 「고칠 수 있다」는 단서. 갤러리가 쓰던 것과 같은 먹색 연필이다.
                    // 원과 같은 비율로 자란다 — 아이폰의 97 대 25 를 그대로 쓴다.
                    Image(systemName: "pencil")
                        .font(.system(size: 12 * sidebarBadgeScale, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 25 * sidebarBadgeScale,
                               height: 25 * sidebarBadgeScale)
                        .background(Circle().fill(Color.doodlePrimary))
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 3)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("프로필 사진 변경")

            // 이름은 **따로 누른다.** 아이폰이 쓰는 것을 그대로 가져와
            // 이름 고치는 창까지 같이 온다 — 한때 여기에 글자만 두어 고칠 길이 없었다.
            ProfileNameView(profileName: $userName, scale: sidebarBadgeScale)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Self.sidebarProfilePadding)
        // 사이드바가 실제로 받은 폭을 재 둔다. 프로필 크기를 여기서 끌어낸다.
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
            sidebarWidth = $0
        }
    }

}

#Preview {
    RootView()
        .modelContainer(LocalDataStore.makePreviewContainer())
}
