//
//  GalleryPage.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/5/26.
//

import SwiftData
import SwiftUI

struct GalleryPage: View {

    /// 상세를 열고 닫을 때 바깥에 알린다. 루트가 이때 사이드바를 접는다.
    var onDetailChange: ((Bool) -> Void)?

    /// 바깥에서 상세를 닫으라는 신호. 값이 바뀌면 닫는다.
    ///
    /// 사이드바를 다시 펼칠 때 쓴다 — 둘이 함께 서면 격자가 2열까지 눌린다.
    /// 값 자체에는 뜻이 없고 **바뀌었다는 사실**만 쓴다.
    var closeDetailSignal: Int = 0

    /// 사이드바가 펼쳐져 있는지. 제목 줄에 세그먼트와 아바타를 세울지 정하는 데 쓴다.
    var isSidebarVisible = false

    /// 바깥에서 프로필 그림을 고르라는 신호. 사이드바의 신원 덩이를 누르면 온다.
    var chooseProfileSignal: Int = 0

    @Query(filter: #Predicate<Post> { $0.isProfile }) private var profilePosts: [Post]

    /// 남이 나를 그려 준 것들. 「나를 그린」 묶음과 같은 조건이라 그리드와 늘 같은 것을 본다.
    ///
    /// 내보내기가 이것을 통째로 가져간다 — 고르는 단계 없이 받은 것을 전부 카드로 만든다.
    @Query(filter: #Predicate<Post> { !$0.isMine },
           sort: \Post.createdAt, order: .reverse) private var receivedPosts: [Post]

    /// 내가 남을 그려 준 것들. 「내가 그린」 묶음과 같은 조건이다.
    @Query(filter: #Predicate<Post> { $0.isMine && !$0.isProfile },
           sort: \Post.createdAt, order: .reverse) private var myPosts: [Post]

    /// 지금 보고 있는 묶음. 내보내기가 이것을 통째로 가져간다.
    private var postsInSection: [Post] {
        GallerySection(rawValue: segmentedBar) == .receivedFromOthers ? receivedPosts : myPosts
    }

    /// 지금 보고 있는 것이 내가 그린 것인지. 카드 제목의 두 이름이 자리를 바꾼다.
    private var isShowingMine: Bool {
        GallerySection(rawValue: segmentedBar) != .receivedFromOthers
    }

    private var profilePost: Post? { profilePosts.first }

    @Environment(\.modelContext) private var modelContext

    /// 지금 보고 있는 섹션. 그리기·공유 화면이 저장을 마치고 여기에 적어 둘 수 있어야 해서
    /// `@State` 가 아니라 저장소를 통해 오간다.
    @AppStorage(GallerySection.storageKey) private var segmentedBar = GallerySection.receivedFromOthers.rawValue
    /// 카드를 늘어놓는 순서. 두 섹션이 함께 쓴다.
    @AppStorage(GallerySortOrder.storageKey) private var sortOrder = GallerySortOrder.newestFirst.rawValue
    @AppStorage("userName") private var inputName = ""

    @State private var mode: GalleryMode = .browsing
    /// 지우려고 확인 팝업을 띄운 그림. 카드를 꾹 눌러 곧장 한 장을 지우는 길이다.
    @State private var postPendingDelete: Post?
    /// 여러 장을 골라 지우려고 표시해 둔 것들.
    @State private var selectedPosts: Set<PersistentIdentifier> = []
    /// 골라 둔 것들을 정말 지울지 묻는 중인지.
    @State private var isConfirmingBulkDelete = false
    /// 지금 고르는 것이 지우려는 것인지 내보내려는 것인지.
    ///
    /// 들어온 길이 정한다 — 카드를 꾹 누르면 지우기, 상단 􀈂 를 누르면 내보내기.
    /// 고른 그림들을 카드로 만들어 보여 줄지.
    @State private var showExportPreview = false
    /// 여러 장 저장을 마치고 띄울 말. 비어 있으면 확인창이 뜨지 않는다.
    @State private var saveResultMessage: String?
    /// 저장하는 동안 같은 버튼을 또 누르지 못하게 막는다.
    @State private var isSavingToPhotos = false
    @State private var selectedPost: Post?
    @State private var profileCandidatePost: Post?
    @State private var showSharingScreen = false
    /// 카드를 꾹 눌러 "그림 공유하기" 를 고른 경우. 이 그림을 들고 멀티피어 화면을 연다.
    @State private var sharingPost: Post?
    /// 헤더 높이. 그리드를 헤더 아래에 붙이는 데 쓴다.
    @State private var headerHeight: CGFloat = 0
    /// 방금 받아서 보여줘야 할 그림. 그리드가 그 자리로 스크롤하고 비운다.
    @State private var postToShow: Post.ID?
    @State private var confettiTrigger = 0

    /// 화면이 실제로 준 폭. 넓은 화면에서 헤더를 키우는 데 쓴다.
    /// 처음 한 번은 아이폰 본문 폭으로 두어, 재기 전에도 엉뚱한 크기가 스치지 않게 한다.
    @State private var contentWidth: CGFloat = DoodleLayout.baseContentWidth
    /// 화면 높이. 가로로 눕혔을 때 세로값을 덜 키우는 데 쓴다.
    @State private var contentHeight: CGFloat = DoodleLayout.baseHeight
    /// 화면(또는 창) 전체 크기. 옆 칸을 펼칠지 정하는 데만 쓴다.
    /// 본문 폭(`contentWidth`)은 옆 칸이 열리면 줄어들므로 판정에 쓸 수 없다.
    @State private var screenSize = CGSize(width: DoodleLayout.baseContentWidth,
                                           height: DoodleLayout.baseHeight)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// 아이폰 기준값을 지금 화면에 맞게 환산한다. 아이폰에서는 늘 1 배다.
    private var layoutScale: CGFloat {
        DoodleLayout.scale(forWidth: contentWidth, sizeClass: horizontalSizeClass)
    }

    /// 세로로 놓이는 값에 쓰는 배율. 가로로 누우면 높이가 모자라 덜 키운다.
    /// 머리말(프로필·이름·세그먼트)이 쓰는 배율.
    ///
    /// 머리말은 **세로 공간을 먹는다.** 그래서 가로 폭이 아니라 세로 높이를 봐야 한다.
    ///
    /// 폭으로 재면 방향이 거꾸로 간다 — 11인치를 눕히면 폭 1210 이라 배율이 1.7 로 오르는데,
    /// 정작 그때가 세로 834 로 가장 짧다. 세로가 제일 모자란 곳에서 머리말이 제일 커져,
    /// 카드(411)가 남은 자리(396)보다 커지고 첫 줄 세 장이 모두 아래가 잘렸다.
    private var headerScale: CGFloat { verticalScale }


    /// 조작부(버튼·세그먼트)가 쓰는 배율. 머리말 배율과 달리 **방향을 타지 않는다.**
    private var chromeScale: CGFloat {
        DoodleLayout.chromeScale(forWidth: contentWidth,
                                 height: contentHeight,
                                 sizeClass: horizontalSizeClass)
    }

    private var verticalScale: CGFloat {
        DoodleLayout.verticalScale(forWidth: contentWidth,
                                   height: contentHeight,
                                   sizeClass: horizontalSizeClass)
    }

    private var isChoosingProfile: Bool { mode == .choosingProfile }
    private var isSelecting: Bool { mode == .selecting }

    /// 저장소에 남은 숫자를 뜻이 있는 값으로 풀어 준다.
    /// 모르는 값이 들어 있으면 처음 열었을 때의 순서로 돌아간다.
    private var currentSortOrder: GallerySortOrder {
        GallerySortOrder(rawValue: sortOrder) ?? .newestFirst
    }

    /// 프로필로 쓸 그림을 고르는 흐름 안에 있는지.
    ///
    /// 들어오는 길이 둘이다.
    /// 프로필 원을 눌러 그리드에서 고르거나, 카드를 꾹 눌러 곧장 확인창을 띄우거나.
    ///
    /// 예전에는 화면 처리를 `mode` 에만 걸어 두어 두 번째 길에서는
    /// 어두운 막도, 세그먼트 바탕도, 툴바 숨김도 걸리지 않았다.
    /// 같은 확인창이 열 때마다 다른 얼굴로 떠서 제멋대로인 것처럼 보였다.
    private var isPickingProfile: Bool {
        isChoosingProfile || profileCandidatePost != nil
    }

    // Figma `iPhone 17 - 1` 기준 치수
    /// 프로필 원 지름. Figma `iPhone 17 - 12` 의 `Frame 1`(92:715).
    private static let profileDiameter: CGFloat = 97
    /// 연필 뱃지 지름
    private static let profileBadgeDiameter: CGFloat = 25
    /// 뱃지가 프로필 원 오른쪽 끝에서 안으로 들어와 있는 정도.
    private static let profileBadgeInset: CGFloat = 4
    /// 뱃지를 누를 수 있는 자리의 지름.
    ///
    /// 보이는 25 는 손끝으로 겨누기에 작다.
    /// 그렇다고 앱 공통 규격인 44 까지 키우지는 않는다.
    /// 그만큼 넓히면 사진의 오른쪽 아래 귀퉁이가 통째로 눌리는 자리가 되어,
    /// 뱃지로 옮긴 이유였던 "사진을 눌렀는데 설정이 열린다" 가 그대로 돌아온다.
    private static let profileBadgeTapDiameter: CGFloat = 36
    /// 본문 좌우 여백.
    ///
    /// Figma 는 세그먼트(`Frame 2`)와 메모지 그리드(`Frame 28`) 를 둘 다 x=20, 폭 362 로 둔다.
    /// 예전에는 세그먼트에만 여백을 더 줘서 그리드가 좌우로 더 튀어나왔다.
    /// 한 값으로 묶어 두 줄의 끝이 어긋날 수 없게 한다.
    private static let baseContentInset: CGFloat = 20

    /// 바깥 여백이 카드 사이 간격보다 얼마나 더 넓어야 하는지.
    private static let outerInsetRatio: CGFloat = 1.2

    /// 본문 좌우 여백.
    ///
    /// **바깥이 안쪽보다 넓어야 한다.** 20 으로 못박아 두었더니 카드 사이(22)보다 좁아,
    /// 격자가 화면 밖으로 흘러내리는 것처럼 보였다. 아이폰은 2열이라 간격이 한 번뿐이어서
    /// 2pt 차이가 묻히지만, 6열에서는 같은 간격이 다섯 번 반복되어 눈이 끝과 비교한다.
    ///
    /// 좁은 화면은 손대지 않는다. 아이폰은 2열이라 간격이 한 번뿐이고,
    /// 여기를 26.4 로 넓히면 카드 폭부터 그리드 전체가 밀려 지금까지의 화면이 달라진다.
    /// 아이폰의 20 대 22 는 별도 항목으로 남긴다.
    private var contentInset: CGFloat {
        guard DoodleLayout.isWide(contentWidth, sizeClass: horizontalSizeClass) else {
            return Self.baseContentInset
        }
        return max(Self.baseContentInset,
                   PostGridView.columnSpacing(forWidth: contentWidth) * Self.outerInsetRatio)
    }
    /// 프로필 블록이 시작하는 높이.
    ///
    /// Figma `iPhone 17 - 12` 는 원의 윗변을 129 에 둔다.
    /// 원이 `offset(y: 5)` 로 내려가 있으므로 자리 자체는 그보다 5 위에서 시작한다.
    private static let headerTopInset: CGFloat = 124
    /// 화면 제목이 놓이는 높이. Figma 의 y=70. 오른쪽 위 버튼들도 같은 줄에 선다.
    private static let titleTopInset: CGFloat = 70
    /// 오른쪽 위 버튼 둘 사이.
    /// Figma 는 정렬(`Frame 40`, 276~320)과 공유받기(`Frame 25`, 338~382)를 18 띄운다.
    private static let topButtonSpacing: CGFloat = 18
    /// 프로필 확인창이 놓이는 높이. Figma `iPhone 17 - 16` 의 `Alert` y=390.
    private static let confirmPopupTop: CGFloat = 390

    // MARK: - 접힌 머리말 (넓은 화면)

    // MARK: 접힌 머리말의 프로필 — 제목에 매단다

    /// 이 화면의 제목 글자 크기. 접힌 머리말의 치수가 전부 여기서 나온다.
    ///
    /// 본문 칸이 아니라 **화면(창) 전체**를 본다.
    /// 칸 폭을 보면 사이드바를 여닫을 때마다 제목과 프로필이 같이 커졌다 작아진다 —
    /// 13인치 세로에서 칸이 1032 에서 712 로 줄면 제목 57.4 → 47.7,
    /// 아바타 100.5 → 83.5 로 주저앉았다. 신원과 제목은 창을 어떻게 나누든 같은 크기여야 한다.
    /// 메모·메일도 사이드바를 연다고 본문 제목이 작아지지 않는다.
    private var wideTitleSize: CGFloat {
        DoodleLayout.titleSize(forWidth: screenSize.width,
                               height: screenSize.height,
                               sizeClass: horizontalSizeClass)
    }

    /// 접힌 머리말의 프로필 원 지름.
    ///
    /// **제목에 매단다.** 고정값에 `headerScale` 을 곱하던 때에는 방향을 바꿀 때마다
    /// 아바타만 흔들렸다 — 제목은 짧은 변 기준이라 13인치에서 세로·가로 모두 57.4 인데,
    /// 아바타는 세로 배율을 따라 100 ↔ 87 로 13% 씩 오갔다.
    /// 같은 줄 바로 아래에서 한쪽만 움직이면 눈에 띈다.
    ///
    /// 1.75 배인 까닭 — 접기 전 아이폰 배치에서는 아바타가 머리말의 주인공이라
    /// 97 대 34, 곧 2.85 배였다. 접은 뒤로는 제목이 줄의 주인공이라 한때 1.5 로 내렸는데,
    /// 그러면 **이름에 견주어 원이 작아 보였다** — 아바타 대 이름이 아이폰에서는 4.9 배인데
    /// 1.5 로는 2.5 배까지 내려가 이름만 도드라졌다. 1.75 면 3 배로, 신원 칩의 통상 비율에 든다.
    private var wideProfileDiameter: CGFloat { wideTitleSize * Self.profileToTitle }
    private static let profileToTitle: CGFloat = 1.75

    /// 접힌 머리말의 이름 글자 크기.
    /// 아이폰이 지키던 이름 대 제목 비율(20 대 34)을 그대로 쓴다.
    private var wideNameSize: CGFloat { wideTitleSize * Self.nameToTitle }
    private static let nameToTitle: CGFloat = 20.0 / 34.0

    /// 접힌 머리말에서 프로필 덩이가 줄어드는 비율.
    /// 뱃지도 같은 비율로 줄여, 원과 연필의 관계를 아이폰과 똑같이 지킨다.
    private var wideProfileRatio: CGFloat { wideProfileDiameter / Self.profileDiameter }

    /// 접힌 머리말에서 프로필 원과 이름 사이. 이것도 제목과 같은 배율로 자란다.
    private var wideProfileSpacing: CGFloat {
        Self.baseProfileSpacing * wideTitleSize / DoodleLayout.titleFontSize
    }
    private static let baseProfileSpacing: CGFloat = 12

    /// 제목 한 줄이 차지하는 높이를 글자 크기에서 어림하는 계수 (SF Pro 한 줄).
    private static let titleLineFactor: CGFloat = 1.21

    /// 제목 줄과 접힌 둘째 줄 사이.
    private static let wideHeaderGap: CGFloat = 12

    /// 머리말과 격자 사이. 아이폰에서 세그먼트 아래에 두던 것과 같은 값이다.
    private static let headerToGrid: CGFloat = 20

    /// 카드 상세를 **옆 칸**에 펼칠지.
    ///
    /// 애플 HIG 「Split views」 — *Prefer using a split view in a regular — not a compact —
    /// environment. A split view needs horizontal space in which to display multiple panes.*
    /// 격자에서 카드를 골라 상세로 가는 것은 메일·메모가 목록과 본문을 나눠 놓는 것과 같은 관계다.
    ///
    /// **눕혔을 때만 편다.** 세로(1032)에서 나누면 격자 3열과 카드 400 으로 양쪽 다 좁아진다.
    /// 같은 문서의 *account for narrow, compact, and intermediate window widths* 에 해당한다.
    /// 아이폰은 compact 라 같은 문서가 split 을 쓰지 말라고 한다.
    private var isSplitLayout: Bool {
        guard selectedPost != nil,
              DoodleLayout.isWide(screenSize.width, sizeClass: horizontalSizeClass),
              screenSize.width > screenSize.height
        else { return false }

        // **사이드바와 상세 칸 중 하나만 넓이를 가져간다.**
        //
        // 사이드바를 펼치면 이 화면이 받는 폭이 1376 에서 1056 으로 줄어든다.
        // 거기서 상세까지 502 를 떼면 격자가 554 만 남아 **2열**로 주저앉는다 —
        // 목록을 반으로 줄여 가며 옆에 한 장을 띄우는 꼴이라 얻는 것보다 잃는 것이 크다.
        // 그때는 나누지 않고 덮는다. 메일·메모가 좁은 창에서 하는 것과 같다.
        return screenSize.width - PostDetailView.preferredPaneWidth >= Self.minGridWidth
    }

    /// 상세를 옆에 두고도 격자가 제 구실을 하려면 이만큼은 남아야 한다.
    /// 이 아래로 내려가면 열이 둘까지 떨어진다.
    private static let minGridWidth: CGFloat = 700

    /// 옆 칸이 가져가는 폭. 열려 있지 않으면 0 이라 본문이 화면을 다 쓴다.
    ///
    /// HIG 의 기본값(주 1/3 · 부 2/3)을 뒤집는다. 그쪽은 목록에서 문서로 가는 관계라
    /// 본문이 넓어야 하지만, 여기 상세는 **고정 비율 카드 한 장**이라 더 넓혀도 커지지 않는다.
    /// 남는 넓이는 격자가 쓰는 편이 낫다.
    private var detailPaneWidth: CGFloat {
        guard isSplitLayout else { return 0 }
        return min(PostDetailView.preferredPaneWidth, screenSize.width * Self.detailPaneShare)
    }

    /// 옆 칸이 가져갈 수 있는 최대 몫.
    private static let detailPaneShare: CGFloat = 0.42

    /// 제목 줄에 묶음 세그먼트를 세울지.
    ///
    /// 사이드바가 펼쳐져 있고 화면이 **서 있으면** 세우지 않는다.
    /// 세로(1032)에서 사이드바가 320 을 가져가면 줄에 712 만 남는데,
    /// 제목·세그먼트(440)·버튼 셋이 그 안에 들어가지 못해 서로 겹친다.
    /// 그때는 사이드바가 묶음을 고르는 일을 맡으므로 같은 것을 두 번 둘 이유도 없다.
    private var showsSegmentInTitleLine: Bool {
        guard isWideLayout else { return false }
        guard isSidebarVisible, contentHeight > contentWidth else { return true }
        return false
    }

    /// 머리말을 두 줄로 접을지.
    ///
    /// 좁고 긴 화면에서는 접지 않는다 — 가로로 늘어놓을 자리가 없고,
    /// 세로로 쌓은 지금 배치가 아이폰에서는 맞다.
    private var isWideLayout: Bool {
        DoodleLayout.isWide(contentWidth, sizeClass: horizontalSizeClass)
    }

    /// 제목 줄에 선 세그먼트가 위에서 떨어지는 거리.
    ///
    /// 오른쪽 버튼 셋과 **세로 가운데를 맞춘다.** 제목 글자보다 둘 다 낮으므로
    /// 제목에 맞추면 버튼과 어긋나 보인다.
    /// 제목 줄이 시작하는 높이.
    ///
    /// 좁은 화면은 Figma 의 70 그대로. 넓은 화면에서는 줄 한가운데 선 세그먼트가
    /// 떠 있는 탭 바를 피해야 해서 **줄 전체가** 그만큼 내려간다 —
    /// 셋 중 하나만 내리면 한 줄로 읽히지 않는다. 실제로 세그먼트만 17pt 처져 있었다.
    private var titleLineTop: CGFloat {
        let base = Self.titleTopInset * verticalScale
        return isWideLayout ? base + Self.segmentToTabBar * chromeScale : base
    }

    /// 제목 줄의 높이. 줄에서 가장 큰 것(제목 글자)이 정한다.
    private var titleLineHeight: CGFloat { wideTitleSize * Self.titleLineFactor }

    /// 제목 줄에 서는 것을 **세로 가운데**로 맞춘다.
    ///
    /// 제목·버튼·세그먼트는 키가 제각각이라(69.5 · 60 · 47.7) 위를 맞추면 줄로 안 보인다.
    /// 좁은 화면은 지금까지처럼 위를 맞춘다 — 아이폰 화면이 한 픽셀도 달라지지 않게.
    private func headerLineTop(for height: CGFloat) -> CGFloat {
        guard isWideLayout else { return Self.titleTopInset * verticalScale }
        return titleLineTop + (titleLineHeight - height) / 2
    }

    private var wideSegmentTop: CGFloat {
        headerLineTop(for: GallerySegmentedControl.trackHeight * chromeScale)

    }

    /// 제목 줄 전체를 아래로 내리는 정도.
    ///
    /// 떠 있는 탭 바는 `safeAreaInsets` 에 잡히지 않아 실제로 재도 알 수 없다.
    /// 실측한 알약 밑변(세로 93.5 · 가로 71)과 세그먼트 윗변 사이에
    /// 손가락 하나 들어갈 틈이 남는 만큼만 잡았다.
    private static let segmentToTabBar: CGFloat = 6

    /// 접힌 둘째 줄이 시작하는 높이.
    ///
    /// 제목이 화면을 따라 커지므로 고정값을 쓸 수 없다 — 넓은 화면에서 제목과 겹친다.
    /// 제목 줄(위 70 + 글자 한 줄) 바로 아래로 내려온다.
    private var wideHeaderTop: CGFloat {
        // 셋이 한 줄에 가운데로 맞춰 서므로 줄 밑변 하나만 보면 된다.
        titleLineTop + titleLineHeight + Self.wideHeaderGap * headerScale
    }

    /// 넓은 화면에서 격자가 시작하는 높이. 제목 줄 하나가 곧 머리말이다.
    private var wideGridTop: CGFloat {
        titleLineTop + titleLineHeight + Self.headerToGrid * headerScale
    }


    /// 프로필 고르기에는 취소 버튼이 없다. 카드가 아닌 빈 곳을 누르면 빠져나온다.
    ///
    /// 여러 장 고르기는 여기 걸지 않는다.
    /// 아래에 「취소」가 서 있고, 카드 사이 빈 자리를 스치듯 눌렀다고
    /// 골라 둔 것이 통째로 날아가면 다시 처음부터 골라야 한다.
    private var emptyAreaTapAction: (() -> Void)? {
        isChoosingProfile ? { exitSelection() } : nil
    }

    /// 화면을 덮는 것이 떠 있으면 툴바·탭바를 숨긴다.
    ///
    /// `alert` 는 스스로 화면을 덮으므로 여기 넣지 않는다.
    /// 넣어 두면 확인창이 뜰 때마다 탭바가 사라졌다 돌아오며 화면이 흔들린다.
    private var isOverlayShowing: Bool {
        selectedPost != nil || isPickingProfile || isSelecting
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Figma `iPhone 17 - 14/15/16` 의 평평한 바탕.
                // 종이 질감은 이 화면에서 은퇴했다.
                Color.doodleBackground
                    .ignoresSafeArea()

                // 화면(창) 전체 크기를 재 둔다. 옆 칸을 펼칠지 여기서 정한다.
                GeometryReader { proxy in
                    Color.clear
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { screenSize = $0 }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // 프로필을 고르는 동안 종이 바탕만 어둡게 깔린다.
                //
                // Figma `iPhone 17 - 15` 의 층 순서를 그대로 따른다.
                // 이 막 **위**에 남는 것 = 고를 수 있는 것: 프로필 원·이름·세그먼트·카드.
                // 아래에 남는 것 = 바탕.
                // 취소 버튼이 없으므로 어두운 곳을 눌러 빠져나온다.
                if isPickingProfile {
                    Color.doodleChoosingScrim
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { exitSelection() }
                        .transition(.opacity)
                }

                // Figma 의 라지 타이틀. (20, 70) 에 34pt Bold.
                //
                // 시스템 `navigationTitle` 을 쓰지 않는다.
                // 이 화면은 ZStack 이 안전영역을 무시하며 자리를 직접 잡고 있어,
                // 네비게이션 바가 끼어들면 프로필 원부터 아래가 통째로 밀린다.
                HStack(spacing: Self.topButtonSpacing * chromeScale) {
                    // 사이드바를 여닫는 단추는 두지 않는다.
                    //
                    // 분할 뷰가 이미 화면 왼쪽 위에 떠 있는 단추로 세워 준다.
                    // 여기 하나 더 두었더니 똑같은 것이 위아래로 둘이 되었고,
                    // 시스템 것을 빼려 해도 빠지지 않는다 — 툴바 항목이 아니라
                    // 분할 뷰 자신의 것이라 `toolbar(removing: .sidebarToggle)` 이 닿지 않는다.
                    Text("갤러리")
                        .font(.system(size: isWideLayout
                                      ? wideTitleSize
                                      : DoodleLayout.titleSize(forWidth: contentWidth,
                                                               height: contentHeight,
                                                               sizeClass: horizontalSizeClass),
                                      weight: .bold))
                        .kerning(DoodleLayout.titleKerning)
                        .foregroundStyle(Color.doodleTitle)
                        .allowsHitTesting(false)
                }
                // 줄 높이는 넓은 화면에서만 못박는다 — 토글 단추를 제목과 세로 가운데로 맞추는 몫이다.
                // 좁은 화면에서는 단추가 없으므로 글자 제 높이 그대로 두어 예전과 같게 남긴다.
                .frame(height: isWideLayout ? titleLineHeight : nil)
                .padding(.leading, contentInset)
                .padding(.top, headerLineTop(for: titleLineHeight))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                // 정렬·공유받기. 제목과 같은 높이(y=70)의 오른쪽 끝에 나란히 뜬다.
                //
                // 화면을 덮는 것이 떠 있으면 제목과 함께 물러난다.
                // **고르는 중에는 내보내기만 남는다** — 고른 것으로 카드를 만들러 가는 길이라
                // 그때가 오히려 가장 쓸 때다. 정렬과 받기는 지금 할 일이 아니라 물러난다.
                if !isOverlayShowing || mode == .selecting {
                    HStack(spacing: Self.topButtonSpacing * chromeScale) {
                        if canExport { exportButton }
                        if mode != .selecting {
                            moreMenu
                            receiveButton
                        }
                    }
                    .padding(.top, headerLineTop(for: DoodleMetrics.side(scale: chromeScale)))
                    .padding(.trailing, contentInset + detailPaneWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }

                // 넓은 화면에서는 세그먼트가 제목 줄 **한가운데**에 선다.
                //
                // 제목(왼쪽) · 세그먼트(가운데) · 버튼 셋(오른쪽)으로 줄을 셋이 나눠 가지면
                // 빈 자리가 한 덩이로 몰리지 않는다. 사진 앱이 제목·기간 고르개·동작을
                // 같은 방식으로 놓는다.
                //
                // 자리는 **화면 중앙** 기준이다. 제목이나 버튼 폭이 달라져도 흔들리면 안 된다.
                // 그래서 둘 사이에 끼워 넣지 않고 ZStack 이 직접 가운데로 보낸다.
                //
                // 고르는 중에도 남는다. 프로필로 쓸 그림은 받은 것 중에도, 내가 그린 것 중에도
                // 있어서 고르는 동안에도 두 묶음을 오갈 수 있어야 한다.
                if showsSegmentInTitleLine {
                    segmentedControl
                        .frame(width: DoodleLayout.controlMaxWidth)
                        .padding(.top, wideSegmentTop)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        // 옆 칸이 열리면 남은 왼쪽 칸의 한가운데로 옮겨 간다.
                        .padding(.trailing, detailPaneWidth)
                }

                // 머리말 — 프로필 원·이름과 (넓은 화면에서는) 세그먼트.
                //
                // 좁은 화면은 세로로 쌓는다. 넓은 화면은 **두 줄로 접는다** —
                // 아이폰 배치를 그대로 늘리면 머리말이 13인치 가로에서 화면의 37% 를 먹어,
                // 폭이 35% 넓어지고 열이 4→6 으로 늘어도 보이는 장수가 세로와 똑같이 12장이었다.
                // 회전이 아무것도 바꾸지 못하는 상태였다.
                //
                // 접으면 정렬 축도 넷에서 둘로 준다 —
                // 제목·프로필이 왼쪽, 버튼 셋·세그먼트가 오른쪽.
                // 넓은 화면에는 프로필 줄이 없다.
                //
                // 신원은 사이드바 맨 위로 옮겼다 — 거기서는 세로로 크게 설 자리가 있어
                // 아이폰의 낯익은 덩이(원 위, 이름 아래)를 그대로 쓸 수 있다.
                // 본문에 있던 때에는 거의 흰 배경 위에 흰 원이 그림자로만 떠 있어 겉돌았고,
                // 신원 하나가 줄 하나(약 130pt)를 통째로 썼다.
                // 사이드바를 접었을 때는 버튼 줄 끝에 작은 아바타가 대신 선다.
                if !isWideLayout {
                    profileBlock
                        .padding(.top, Self.headerTopInset * verticalScale)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                        .padding(.horizontal, contentInset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .allowsHitTesting(!isPickingProfile)
                }

                // 세그먼트와 그리드.
                //
                // 좁은 화면에서 세그먼트가 머리말이 아니라 여기 있는 이유가 있다.
                // 프로필로 쓸 그림은 받은 것 중에도, 내가 그린 것 중에도 있어서
                // 고르는 동안에도 두 섹션을 오갈 수 있어야 한다.
                // 접힌 배치에서도 세그먼트는 어두운 막 **위**에 있으므로 같은 뜻이 지켜진다.
                VStack(spacing: 0) {
                    if !isWideLayout {
                        segmentedControl
                            .padding(.bottom, Self.headerToGrid * headerScale)
                    }

                    PostGridView(
                        mode: mode,
                        segmentedBar: $segmentedBar,
                        sortOrder: currentSortOrder,
                        selectedPost: $selectedPost,
                        showsDetailBeside: isSplitLayout,
                        profileCandidatePost: $profileCandidatePost,
                        postPendingDelete: $postPendingDelete,
                        selectedPosts: $selectedPosts,
                        onShare: { sharingPost = $0 },
                        onStartSelecting: { startSelecting(with: $0) },
                        postToShow: $postToShow,
                        onEmptyAreaTap: emptyAreaTapAction
                    )
                }
                .padding(.horizontal, contentInset)
                // 접힌 배치에서는 세그먼트가 머리말 안에 있으므로 그 아래 틈을 여기서 준다.
                .padding(.top, isWideLayout ? wideGridTop : headerHeight)
                // 옆 칸이 열리면 격자가 그만큼 좁아지고, 열 수도 스스로 줄어든다.
                .padding(.trailing, detailPaneWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .onChange(of: chooseProfileSignal) { _, _ in
                    withAnimation(.spring()) { mode = .choosingProfile }
                }
                .onChange(of: closeDetailSignal) { _, _ in
                    withAnimation(PostGridView.cardTransition) { selectedPost = nil }
                }
                // 상세를 열고 닫을 때 루트에 알린다. 루트가 사이드바를 접는다.
                .onChange(of: selectedPost?.persistentModelID) { _, id in
                    onDetailChange?(id != nil)
                }
                // 본문이 실제로 받은 폭을 재 둔다. 헤더 크기를 여기서 끌어낸다.
                .onGeometryChange(for: CGSize.self) { $0.size } action: {
                    contentWidth = $0.width
                    contentHeight = $0.height
                }

                // 프로필로 앉힐지 묻는 확인창. Figma `iPhone 17 - 16`.
                //
                // 화면 위에서 390 — 세그먼트 바로 아래다.
                // 한가운데로 보내면 방금 고른 카드를 덮어, 무엇을 고른 건지 보이지 않는다.
                if profileCandidatePost != nil {
                    DoodleConfirmPopup(
                        title: "프로필 사진으로 설정하시겠습니까?",
                        cancelTitle: "아니오",
                        confirmTitle: "예",
                        // 「취소」 는 확인창만 닫는 것이 아니라 **갤러리로 돌아간다.**
                        //
                        // 예전에는 확인창만 닫혀 고르기 모드에 그대로 남았다.
                        // 그런데 이 모드에는 무엇을 하라는 말도, 나가는 길도 보이지 않는다 —
                        // 빈 곳을 눌러야 빠져나가는데 그건 눈에 띄지 않는 길이다.
                        // 「취소」 가 나가는 길을 겸하면 막대를 따로 세우지 않아도 된다.
                        //
                        // 다른 그림으로 바꾸려면 ✎ 를 한 번 더 누르면 된다.
                        onCancel: {
                            withAnimation(.spring(response: 0.3)) {
                                profileCandidatePost = nil
                                mode = .browsing
                            }
                        },
                        onConfirm: {
                            confirmProfile()
                        }
                    )
                    .padding(.top, Self.confirmPopupTop)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }

                // 카드 상세.
                //
                // 눕힌 아이패드에서는 **오른쪽 칸**으로 들어간다 (메모·메일과 같은 두 칸 배치).
                // 격자가 그대로 남아 어느 카드를 보고 있는지 계속 보이고,
                // 다른 카드를 눌러 옮겨 다닐 수 있다.
                if let selectedPost, isSplitLayout {
                    PostDetailView(post: selectedPost, chromeScale: chromeScale) {
                        withAnimation(PostGridView.cardTransition) { self.selectedPost = nil }
                    }
                    // 카드를 바꾸면 상세도 처음부터 시작한다.
                    //
                    // 덮어서 보여 줄 때는 닫았다 여는 것이라 저절로 초기화됐다.
                    // 옆 칸은 뷰가 그대로 살아 있어서, 뒤집어 둔 채 다른 카드를 누르면
                    // 새 카드가 **뒷면부터** 나왔다.
                    .id(selectedPost.persistentModelID)
                    .frame(width: detailPaneWidth)
                    // 칸을 나누는 것은 선이 아니라 재질이다 — 덮어서 보여 줄 때 쓰던 것과 같다.
                    .background(.regularMaterial)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .ignoresSafeArea(edges: .bottom)
                    // 옆에서 밀려 들어온다. 덮는 배치의 「커지며 뜬다」는 여기서 뜻이 맞지 않는다.
                    .transition(.move(edge: .trailing))
                } else if let selectedPost {
                    ZStack {
                        // 흰 장막을 짙게 깔면 종이 질감까지 덮여 화면이 허옇게 뜬다.
                        // 카드도 거의 흰색이라 배경과 구분이 안 됐다.
                        // 반대로 옅게 깔면 질감은 살지만 뒤쪽 카드가 그대로 보여 산만하다.
                        //
                        // 재질을 쓰면 뒤가 흐려져 카드는 정리되고 종이 색은 남는다.
                        Rectangle()
                            .fill(.regularMaterial)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(PostGridView.cardTransition) { self.selectedPost = nil }
                            }

                        PostDetailView(post: selectedPost, chromeScale: chromeScale) {
                            withAnimation(PostGridView.cardTransition) { self.selectedPost = nil }
                        }
                    }
                    // 카드가 있던 자리에서 살짝 커지며 올라온다.
                    //
                    // 투명도만 바꾸면 화면이 통째로 덮이는 느낌이라
                    // 「카드를 확대한다」는 동작과 결이 어긋난다.
                    // 조금 작은 데서 시작해 제 크기로 붙어야 커졌다는 것이 읽힌다.
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                }

                // 여러 장을 고르는 동안 탭바 자리에 서는 막대.
                //
                // 탭바가 물러난 그 자리를 그대로 쓴다.
                // 다른 자리에 띄우면 화면 아래에 눌러야 할 것이 두 층으로 겹쳐 보인다.
                if isSelecting {
                    selectionBar
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // 삭제 중에는 탭바 자리를 선택 바가 대신 쓴다.
            .toolbarVisibility(isOverlayShowing ? .hidden : .visible, for: .tabBar)
            // **위아래만** 무시한다.
            //
            // 제목과 프로필은 화면 맨 위에서 잰 Figma 좌표에 놓여야 해서 세로는 무시해야 하지만,
            // 좌우까지 무시하면 아이패드에서 본문이 **사이드바 밑으로 흘러든다** —
            // iPadOS 26 의 사이드바는 떠 있고, 그 폭을 곁 칸의 안전영역으로 알려 준다.
            // 좌우를 지키면 사이드바가 본문을 밀어내는 것처럼 자리를 나눈다.
            // 아이폰은 세로로 세우면 좌우 안전영역이 0 이라 지금까지와 같다.
            .ignoresSafeArea(.container, edges: .vertical)
            // 보낼 그림 없이 열면 받기 전용으로 동작한다.
            //
            // 그림이 도착하면 공유 화면이 스스로 접히고 여기로 돌아온다.
            // 받은 그림을 들고 오므로 그 자리를 그리드에 일러 준다.
            .fullScreenCover(isPresented: $showSharingScreen) {
                NearbySharingScreen(
                    onClose: { showSharingScreen = false },
                    onReceived: { postToShow = $0.id }
                )
            }
            // 카드를 꾹 눌러 고른 한 장을 들고 여는 경우.
            .fullScreenCover(item: $sharingPost) { post in
                NearbySharingScreen(
                    post: post,
                    onClose: { sharingPost = nil },
                    onReceived: { postToShow = $0.id }
                )
            }
            // 되돌릴 수 없는 일만 물어본다. 이 화면에 남은 물음은 이것 하나다.
            //
            // `confirmationDialog` 는 누른 자리에 앵커되어 꼬리가 달린 채 뜬다.
            // 어느 카드인지는 알려주지만 뜨는 자리가 그때그때 달라 화면이 어수선하다.
            // `alert` 는 언제나 가운데에 꼬리 없이 뜬다.
            //
            // 파괴적 동작이 빨갛게, 취소가 제자리에 오는 배치는 시스템이 알아서 잡아준다.
            .alert(
                "이 그림을 삭제할까요?",
                isPresented: isDeletePresented,
                presenting: postPendingDelete
            ) { post in
                Button("삭제", role: .destructive) { delete(post) }
                Button("취소", role: .cancel) { postPendingDelete = nil }
            } message: { _ in
                Text("삭제한 그림은 되돌릴 수 없어요.")
            }
            // 여러 장을 한꺼번에 지울 때의 확인. 한 장짜리와 같은 이유로 `alert` 을 쓴다.
            //
            // 몇 장인지 제목에 넣는다.
            // 고른 것이 화면 밖에 있을 수 있어, 되돌릴 수 없는 일 앞에서
            // "무엇을 지우는지" 를 숫자로라도 다시 확인시켜 준다.
            .alert(
                "\(selectedPosts.count)장의 그림을 삭제할까요?",
                isPresented: $isConfirmingBulkDelete
            ) {
                Button("삭제", role: .destructive) { deleteSelected() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("삭제한 그림은 되돌릴 수 없어요.")
            }
            // 저장 결과. 상세 화면의 한 장 저장과 같은 방식으로 알린다.
            .alert("사진 저장",
                   isPresented: Binding(get: { saveResultMessage != nil },
                                        set: { if !$0 { saveResultMessage = nil } }),
                   presenting: saveResultMessage) { _ in
                Button("확인") { saveResultMessage = nil }
            } message: { message in
                Text(message)
            }
            .fullScreenCover(isPresented: $showExportPreview) {
                ExportPreviewScreen(
                    pages: exportPages,
                    fileName: "doodleme-\(selectedPosts.count)"
                ) {
                    showExportPreview = false
                }
            }
        }
    }

    /// 고른 그림으로 만들 카드들. 짜는 규칙은 `ExportComposer` 에 있다.
    private var exportPages: [ExportPage] {
        let posts = selectedPosts
            .compactMap { modelContext.registeredModel(for: $0) as Post? }
            .sorted { $0.createdAt > $1.createdAt }
        return ExportComposer.pages(for: posts,
                                    myName: inputName.isEmpty ? "나" : inputName,
                                    mine: isShowingMine)
    }

    // MARK: - 선택 바

    /// 여러 장을 고르는 동안 화면 아래에 서는 막대.
    private var selectionBar: some View {
        HStack {
            Button("취소") { exitSelection() }
                .foregroundStyle(Color.doodlePrimary)

            Spacer()

            // 몇 장 골랐는지 가운데에서 계속 알려준다.
            // 카드가 화면 밖으로 밀려나도 고른 개수는 여기 남는다.
            Text(selectedPosts.isEmpty
                 ? "그림을 선택하세요"
                 : "\(selectedPosts.count)장 선택됨")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.doodleDetail)

            Spacer()

            // 고른 뒤에 무엇을 할지 정한다.
            //
            // 예전에는 들어온 길이 할 일을 정했다 — ⋯ 로 들어오면 삭제만, 상단 􀈂 로 들어오면
            // 내보내기만 섰다. 그래서 세 장을 골라 놓고 마음이 바뀌면 취소하고 다른 길로
            // 들어가 **처음부터 다시 골라야** 했다. 고르는 일은 한 번이면 된다.
            //
            // 글자 대신 글리프를 쓴다. 저장 글리프는 상세 화면 툴바의 저장과 **같은 그림**이라
            // 새로 배울 것이 없다.
            //
            // 내보내기는 여기 두지 않는다. 고르는 동안에도 헤더에 그대로 서 있어
            // 굳이 막대에 한 번 더 둘 이유가 없다.
            //
            // 한 장도 고르지 않았으면 할 일이 없다.
            // 색을 직접 지정하면 시스템이 비활성일 때 걸어 주는 흐림이 덮인다.
            // 눌리지도 않으면서 또렷하게 서 있어, 눌러 보고 나서야 안 된다는 걸 알게 된다.
            // 그래서 흐림도 직접 준다.
            HStack(spacing: Self.selectionActionSpacing * chromeScale) {
                selectionAction("square.and.arrow.down", label: "사진 앱에 저장") {
                    saveSelectedToPhotos()
                }
                selectionAction("trash", label: "삭제", tint: .red) {
                    isConfirmingBulkDelete = true
                }
            }
        }
        .font(.system(size: 17 * chromeScale, weight: .semibold))
        // 막대 안쪽 치수도 함께 자란다. 버튼만 키우면 글자와 버튼이 알약 벽에 붙는다.
        .padding(.horizontal, Self.selectionBarInset * chromeScale)
        .frame(height: DoodleMetrics.side(scale: chromeScale) + Self.selectionBarPadding * chromeScale)
        // 리퀴드 글래스. 흰 캡슐을 직접 그리지 않는다.
        //
        // 애플 HIG 「Materials」 — *Liquid Glass forms a distinct functional layer for controls
        // and navigation elements … that floats above the content layer.*
        // 이 막대는 **탭바가 서 있던 자리**를 그대로 물려받는데, iOS 26 탭바가 이미 유리라
        // 흰 캡슐을 그려 두면 같은 자리에서 재질만 달라진다.
        //
        // 안에 누를 것이 들어 있으므로 `interactive` 를 건다.
        // HIG: *for custom controls or containers with interactive elements, add the
        // interactive modifier to the glass effect.*
        .glassEffect(.regular.interactive(), in: .capsule)
        // 넓은 화면에서 끝까지 늘어나지 않게 막는다.
        //
        // 아이패드 가로(1180)에서 화면 폭을 꽉 채우면 「취소」 가 맨 왼쪽,
        // 「삭제」·「내보내기」 가 맨 오른쪽에 붙어 손이 닿지 않고 가운데만 휑하다.
        // 탭바가 서 있던 자리를 물려받는 막대이므로 탭바처럼 가운데에 모아 둔다.
        // 아이폰(402)에서는 이 값에 닿지 않아 지금과 똑같다.
        .frame(maxWidth: DoodleLayout.controlMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, contentInset)
        .padding(.trailing, detailPaneWidth)
        .padding(.bottom, Self.selectionBarBottomInset * chromeScale)
    }

    /// 선택 바의 동작 하나. 글리프만 서고 이름은 낭독기에게만 간다.
    private func selectionAction(_ symbol: String,
                                 label: String,
                                 tint: Color = .doodlePrimary,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19 * chromeScale, weight: .medium))
                // 넓은 화면에서는 누를 자리를 조작부 규격(44 이상)으로 넓힌다.
                //
                // 30 은 HIG 의 최소 터치 영역 44 에 못 미친다. 아이폰은 이 값이 그대로라
                // 화면이 달라지지 않지만, 30 짜리 터치 영역이 남아 있다는 사실은 따로 남겨 둔다.
                .frame(width: selectionActionSide, height: selectionActionSide)
                .contentShape(Rectangle())
        }
        .foregroundStyle(isSelectionActionEnabled ? tint : Color.doodleMuted)
        .disabled(!isSelectionActionEnabled)
        .accessibilityLabel(label)
    }

    /// 선택 바 동작 버튼의 한 변.
    ///
    /// 좁은 화면은 지금의 30 을 지킨다 — 넓히면 아이콘 자리가 밀려 화면이 달라진다.
    /// 넓은 화면에서는 `DoodleMetrics.side` 를 써서 HIG 의 44 를 처음으로 넘긴다.
    private var selectionActionSide: CGFloat {
        DoodleLayout.isWide(contentWidth, sizeClass: horizontalSizeClass)
            ? DoodleMetrics.side(scale: chromeScale)
            : Self.baseSelectionActionSide
    }

    private static let baseSelectionActionSide: CGFloat = 30

    /// 고른 것이 있고, 저장이 돌고 있지 않을 때만 누를 수 있다.
    private var isSelectionActionEnabled: Bool {
        !selectedPosts.isEmpty && !isSavingToPhotos
    }

    /// 고른 그림들을 사진 앱에 넣는다.
    ///
    /// 내보내기 카드가 아니라 **그린 그대로**를 넣는다 —
    /// 상세 화면의 저장이 하던 일을 여러 장으로 늘린 것이다.
    private func saveSelectedToPhotos() {
        let items = selectedPosts
            .compactMap { modelContext.registeredModel(for: $0) as Post? }
            .sorted { $0.createdAt > $1.createdAt }
            .map(\.photoItem)
        guard !items.isEmpty else { return }

        isSavingToPhotos = true
        Task {
            let outcome = await PhotoLibrarySaver.save(items)
            isSavingToPhotos = false
            saveResultMessage = outcome.message
        }
    }

    /// 선택 바의 동작 사이.
    private static let selectionActionSpacing: CGFloat = 14
    /// 선택 바 알약의 안쪽 좌우 여백.
    private static let selectionBarInset: CGFloat = 24
    /// 버튼 위아래로 알약이 더 갖는 높이.
    private static let selectionBarPadding: CGFloat = 12

    /// 선택 바가 화면 아래에서 떨어져 있는 정도.
    /// 탭바가 서 있던 자리와 같은 높이라 홈 인디케이터를 피한다.
    private static let selectionBarBottomInset: CGFloat = 34

    // MARK: - 상단

    /// 「내가 그린 / 나를 그린」 막대.
    ///
    /// 좁은 배치에서는 격자 위에, 접힌 배치에서는 머리말 오른쪽에 선다.
    /// 두 자리에 각각 적어 두면 한쪽만 고쳐지므로 하나로 묶어 둔다.
    private var segmentedControl: some View {
        // Figma `iPhone 17 - 12` 의 막대.
        // 트랙이 불투명한 흰색이라, 뒤에 어두운 막이 깔려도 배어 나오지 않는다.
        // 크기는 **조작부** 배율을 따른다. 머리말 배율(`headerScale`)을 쓰면
        // 눕혔을 때 44 → 38 로 줄어 아이폰 크기(35)와 구별되지 않았다.
        GallerySegmentedControl(selection: $segmentedBar, scale: chromeScale)
            // 묶음을 옮기면 골라 둔 것을 놓는다.
            //
            // 고르기는 **보고 있는 묶음 안에서만** 뜻이 있다.
            // 그대로 들고 넘어가면 「1장 선택됨」 이라고 하면서 체크된 카드는 한 장도
            // 안 보이고, 그 상태로 내보내면 「케빈이 그린 / 사람들의 첫인상」 아래에
            // 남이 그려 준 그림이 섞여 들어간다 — 구워서 확인했다.
            // 지우기도 마찬가지로 안 보이는 그림을 지우게 된다.
            .onChange(of: segmentedBar) { _, _ in
                selectedPosts = []
            }
    }

    /// 접힌 머리말의 왼쪽 — 프로필 원과 이름이 가로로 나란히 선다.
    ///
    /// 넓은 화면에서는 **원 전체**가 프로필 그림을 고르는 문이다.
    /// 아이폰의 「연필 뱃지만 누를 수 있다」를 여기서 넓히는 것이지 문을 하나 더 내는 것이 아니다 —
    /// 원을 눌러도 연필을 눌러도 가는 곳은 같고 묻는 창도 그대로 없다.
    ///
    /// 넓히는 이유는 손끝이다. 원이 97 에서 64 로 줄면 뱃지도 같은 비율로 줄어
    /// 누를 자리가 36 에서 24 까지 내려간다 — 이미 HIG 의 44 에 못 미치던 것이 더 멀어진다.
    /// 64 짜리 원 전체를 받으면 그 기준을 처음으로 넘는다.
    /// 연필은 「여기를 누르면 바꾼다」를 알려 주는 유일한 단서라 그림으로 남긴다.
    private var wideProfileRow: some View {
        Button {
            withAnimation(.spring()) { mode = .choosingProfile }
        } label: {
            HStack(spacing: wideProfileSpacing) {
                profileCircle(diameter: wideProfileDiameter,
                              badgeScale: wideProfileRatio)
                Text(inputName.isEmpty ? "이름" : inputName)
                    .font(.system(size: wideNameSize, weight: .bold))
                    .foregroundStyle(inputName.isEmpty ? Color.gray : .doodlePrimary)
                    // 좁은 창에서는 세그먼트가 폭을 먼저 가져가므로 이름이 줄임표로 잘린다.
                    // 이름은 다시 볼 수 있지만 묶음을 고르는 막대는 대신할 것이 없다.
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("프로필 사진 변경")
    }

    /// 프로필 그림이 담기는 흰 원. 두 배치가 크기만 달리해 함께 쓴다.
    private func profileCircle(diameter: CGFloat, badgeScale: CGFloat) -> some View {
        ZStack {
            Circle()
                .foregroundStyle(.white)

            if let profilePost {
                DoodleImageView(drawingData: profilePost.drawingData, contentMode: .fill)
            } else {
                DefaultDoodleImage()
                    // 원을 꽉 채우지 않고 지름의 80% 크기로 가운데 놓는다.
                    .frame(width: diameter * 0.8, height: diameter * 0.8)
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.1), radius: 3, x: 2, y: 2)
        .overlay(alignment: .bottomTrailing) {
            // 접힌 배치에서는 뱃지가 버튼이 아니라 그림이다 —
            // 바깥의 원 전체가 이미 같은 곳으로 가는 버튼이라, 여기에 또 버튼을 두면
            // 같은 자리에 버튼이 둘 겹쳐 손쉬운 사용이 같은 항목을 두 번 읽는다.
            badgeScale == 1 ? AnyView(profileEditBadge) : AnyView(profileBadgeMark(scale: badgeScale))
        }
        .overlay { ConfettiBurst(trigger: confettiTrigger) }
    }

    /// 연필 뱃지의 **그림만**. 누르는 몫은 바깥 원이 맡는다.
    /// `scale` 은 아이폰 원(97) 대비 지금 원이 몇 배인지다.
    /// 원 지름에 이미 화면 배율이 들어 있으므로 여기서 또 곱하지 않는다.
    private func profileBadgeMark(scale: CGFloat) -> some View {
        Image(systemName: "pencil")
            .font(.system(size: 12 * scale, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: Self.profileBadgeDiameter * scale,
                   height: Self.profileBadgeDiameter * scale)
            .background(Circle().fill(Color.doodlePrimary))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 3)
            .offset(x: -Self.profileBadgeInset * scale)
    }

    /// 프로필 원과 이름. 세그먼트는 어두운 레이어 위에 있어야 해서 본문 쪽에 있다.
    private var profileBlock: some View {
        // 간격을 기본값에 맡기지 않는다.
        // 기본 간격이 이름의 위 여백에 더해져, 원과 이름 사이가 Figma 보다 벌어졌다.
        VStack(spacing: 0) {
            // 사진 자체는 누를 수 없다. 프로필을 바꾸는 문은 연필 뱃지 하나뿐이다.
            // (넓은 화면에서 접었을 때만 원 전체를 문으로 넓힌다 — `wideProfileRow`.)
            profileCircle(diameter: Self.profileDiameter * headerScale, badgeScale: 1)
                .offset(y: 5)

            ProfileNameView(profileName: $inputName, scale: headerScale)
                // 이 여백이 곧 세그먼트가 놓이는 높이를 정한다.
                // 124(시작) + 97(원) + 12.5(이름 위) + 24(이름) + 36.5 = 294 — Figma `222:1199` 의 y.
                .padding(.bottom, 36.5 * headerScale)
        }
    }

    /// 프로필 사진을 바꾸는 연필 뱃지.
    /// Figma: `#424242` 원 + 흰 연필, 그림자 y3 blur3 검정 20%.
    ///
    /// 프로필 설정으로 들어가는 문은 여기 하나뿐이다.
    /// 예전에는 사진 아무 데나 눌러도 열려서, 그림을 들여다보려고 누른 사람까지
    /// 설정 흐름으로 끌려 들어갔다. 연필은 "고칠 수 있다" 는 뜻으로 이미 그려져 있으니,
    /// 그 뜻대로 여기만 누르게 한다.
    ///
    /// 누르면 곧장 그림을 고르러 간다.
    /// 프로필이 있든 없든 여기서 할 일은 "어느 그림으로 할지 정하기" 하나뿐이라,
    /// 무엇을 할지 고르는 창을 사이에 두지 않는다.
    /// 정말 이 그림으로 할지는 카드를 고른 뒤 확인창이 한 번 묻는다.
    private var profileEditBadge: some View {
        Button {
            withAnimation(.spring()) { mode = .choosingProfile }
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: Self.profileBadgeDiameter * headerScale,
                       height: Self.profileBadgeDiameter * headerScale)
                .background(Circle().fill(Color.doodlePrimary))
                .shadow(color: .black.opacity(0.2), radius: 2, y: 3)
                .frame(width: Self.profileBadgeTapDiameter * headerScale,
                       height: Self.profileBadgeTapDiameter * headerScale)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // 누를 자리를 넓히면 뱃지가 그 절반만큼 원 안쪽으로 밀려난다.
        // 밀린 만큼 되돌려, 보이는 자리는 Figma 그대로 둔다.
        .offset(
            x: Self.profileBadgeTapMargin - Self.profileBadgeInset,
            y: Self.profileBadgeTapMargin
        )
        .accessibilityLabel("프로필 사진 변경")
    }

    /// 보이는 뱃지와 누를 수 있는 자리의 반지름 차이.
    private static var profileBadgeTapMargin: CGFloat {
        (profileBadgeTapDiameter - profileBadgeDiameter) / 2
    }

    // MARK: - 오른쪽 위 버튼

    /// 카드를 늘어놓는 순서를 고르는 메뉴.
    /// Figma `iPhone 17 - 13` 의 `Frame 40`(142:703) · `Frame 41`(142:706).
    ///
    /// 메뉴는 손으로 그리지 않고 시스템 `Menu` 에 맡긴다.
    /// 리퀴드 글래스도, 고른 줄을 짚어 주는 회색 바탕도, 체크 표시도 시스템이 붙여 준다.
    /// Figma 의 `Frame 41`(198x90 · 흰색 80% · 45 짜리 두 줄 · 선택줄 `#DEDEDE` 80%)이
    /// 그리고 있는 것이 바로 그 시스템 메뉴다. 베껴 그리면 겉만 닮고 동작이 어긋난다.
    private var moreMenu: some View {
        Menu {
            ForEach(GallerySortOrder.allCases, id: \.rawValue) { order in
                Button {
                    sortOrder = order.rawValue
                } label: {
                    // 지금 보고 있는 순서에만 체크가 붙는다. Figma `Frame 41` 의 􀆅.
                    if order.rawValue == sortOrder {
                        Label(order.title, systemImage: "checkmark")
                    } else {
                        Text(order.title)
                    }
                }
            }

            // 카드를 꾹 눌러야만 들어갈 수 있던 길을 주 화면에도 낸다.
            //
            // 애플 HIG 「Context menus」 —
            // *Always make context menu items available in the main interface, too.*
            // 내보내기는 􀈂 로 나와 있는데 지우기만 꾹 누르기에 숨어 있어 짝이 맞지 않았다.
            Divider()

            Button {
                startDeleteSelection()
            } label: {
                Label("선택", systemImage: "checkmark.circle")
            }
        } label: {
            // 글리프를 `list.bullet`(정렬) 에서 `ellipsis`(더 보기) 로 바꿨다.
            //
            // 애플 HIG 「Toolbars」 —
            // *Add a More menu to contain additional actions. Prioritize **less important**
            // actions for inclusion in the More menu.*
            // 정렬도 선택도 자주 쓰는 것이 아니라 이 메뉴의 조건에 맞는다.
            //
            // 버튼을 하나 더 세우지 않는 이유도 같은 문서에 있다 —
            // *Choose items deliberately to avoid overcrowding.*
            // 􀈂 내보내기와 􀝎 받기는 이 화면의 주된 두 동작이라 밖에 남는다.
            //
            // 원 크기·재질은 Figma `Frame 41` 그대로다. 바뀐 것은 안의 글리프뿐이다.
            Image(systemName: "ellipsis")
                .font(.system(size: 20 * chromeScale, weight: .medium))
                .foregroundStyle(Color.doodlePrimary)
                .frame(width: DoodleMetrics.side(scale: chromeScale),
                       height: DoodleMetrics.side(scale: chromeScale))
                // Figma: 흰색 80% · 그림자 0 4 15 검정 5%. SwiftUI 반경은 blur 의 절반.
                .background(.white.opacity(0.8), in: Circle())
                .shadow(color: .black.opacity(0.05), radius: 7.5, y: 4)
        }
        .accessibilityLabel("더 보기")
    }

    /// 그림을 받으러 가는 버튼. Figma `iPhone 17 - 13` 의 `Frame 25`(92:612):
    /// (338, 70) 에 44x44, `#424242` 90% 원에 `#F2F2F2` 아이콘.
    ///
    /// 디자인이 흰 원에서 먹색 원으로 뒤집었다.
    /// 옆에 흰 원(정렬)이 하나 더 서면서, 둘 다 흰색이면 무엇이 주된 동작인지 알 수 없어졌다.
    ///
    /// 프로필 설정과 삭제는 카드를 꾹 눌러서 하므로 이 버튼에 메뉴를 달지 않는다.
    /// 누르면 곧장 공유 화면이 열린다.
    ///
    /// 툴바에 두지 않는다. iOS 26 툴바는 항목마다 유리 배경을 깔아 주는데,
    /// 디자인이 정한 것은 색이 찬 원이라 두 겹이 겹쳤다.
    /// 제목이 그랬듯 ZStack 이 직접 자리를 잡으면 Figma 좌표가 그대로 맞는다.
    private var receiveButton: some View {
        Button {
            showSharingScreen = true
        } label: {
            // Figma 글리프 상자가 24. `Frame 6` 이 21 짜리를 18 로 쓰므로 같은 비율로 20.
            Image(systemName: "airplay.audio")
                .font(.system(size: 20 * chromeScale, weight: .medium))
                .foregroundStyle(Color.doodleOnDarkButton)
                .frame(width: DoodleMetrics.side(scale: chromeScale),
                       height: DoodleMetrics.side(scale: chromeScale))
                // Figma: `#424242` 90% · 그림자 0 4 15 검정 5%. SwiftUI 반경은 blur 의 절반.
                .background(Color.doodlePrimary.opacity(0.9), in: Circle())
                .shadow(color: .black.opacity(0.05), radius: 7.5, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("그림 공유받기")
    }

    /// 받은 그림을 카드로 묶어 밖으로 내보내는 버튼.
    ///
    /// 애플 HIG 「Activity views」 — 밖으로 내보내는 일은 공유 기호(􀈂)를 눌러 시작한다.
    /// 「Toolbars」 도 오른쪽 끝을 **늘 닿을 수 있어야 하는 항목**의 자리로 두고,
    /// 항목에는 글자 대신 알아보기 쉬운 기호를 쓰라고 한다.
    ///
    /// 고르는 단계를 두지 않는다.
    /// 「Context menus」 의 *메뉴 항목은 주 화면에도 있어야 한다* 를 지키려고
    /// 선택 바에 「내보내기」 를 끼워 넣었더니 취소·개수·삭제와 함께 네 개가 서서 어수선해졌다.
    /// 여기서 누르면 받은 그림을 **전부** 모아 여섯 장씩 카드로 나눈다 —
    /// 내보내는 것은 「사람들이 그린 나의 첫인상」 한 벌이지 낱장이 아니다.
    ///
    /// 정렬(흰 원)과 공유받기(먹색 원) 사이에서 흰 원 쪽에 선다.
    /// 이 화면의 주된 동작은 그림을 **받는** 것이라 먹색은 그 하나만 쓴다.
    private var exportButton: some View {
        Button {
            // 고르는 중이면 이미 고른 것으로 바로 넘어간다. 아니면 고르기부터 연다.
            if mode == .selecting {
                showExportPreview = true
            } else {
                startExportSelection()
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 20 * chromeScale, weight: .medium))
                .foregroundStyle(isExportButtonEnabled ? Color.doodlePrimary : Color.doodleMuted)
                .frame(width: DoodleMetrics.side(scale: chromeScale),
                       height: DoodleMetrics.side(scale: chromeScale))
                .background(.white.opacity(0.8), in: Circle())
                .shadow(color: .black.opacity(0.05), radius: 7.5, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!isExportButtonEnabled)
        .accessibilityLabel("그림 내보내기")
    }

    /// 고르는 중에는 한 장이라도 골랐을 때만 누를 수 있다.
    private var isExportButtonEnabled: Bool {
        mode != .selecting || !selectedPosts.isEmpty
    }

    /// 내보낼 것이 있는지.
    ///
    /// 두 묶음 모두 낸다. 카드 제목의 두 이름이 자리를 바꿀 뿐이다 —
    /// 「**사람들**이 그린 / **케빈**의 첫인상」 · 「**케빈**이 그린 / **사람들**의 첫인상」.
    /// 한 장도 없으면 눌러도 빈 종이만 나오므로 그때는 버튼을 내지 않는다.
    private var canExport: Bool {
        !postsInSection.isEmpty
    }

    // MARK: - 동작

    // `confirmationDialog` 는 `Bool` 로만 여닫는데, 우리가 든 건 "무엇에 대한 확인인가" 라는 값이다.
    // 값이 있으면 떠 있고 닫히면 비우도록 이어 준다.

    private var isDeletePresented: Binding<Bool> {
        Binding(
            get: { postPendingDelete != nil },
            set: { if !$0 { postPendingDelete = nil } }
        )
    }

    /// 고른 그림을 프로필로 앉힌다.
    ///
    /// 들어오는 길이 둘이지만 끝은 같다.
    /// 연필을 눌러 고르는 화면에서 카드를 누르거나,
    /// 카드를 꾹 눌러 「프로필 사진 설정」을 고르거나 — 둘 다 확인창을 거쳐 여기로 온다.
    private func confirmProfile() {
        guard let candidate = profileCandidatePost else { return }
        modelContext.setProfilePost(candidate)
        confettiTrigger += 1
        withAnimation(.spring()) {
            profileCandidatePost = nil
            mode = .browsing
        }
    }

    /// 카드를 꾹 눌러 「선택」으로 들어온다. 누른 그 카드가 첫 선택이 된다.
    ///
    /// 빈손으로 시작하면 방금 고른 카드를 한 번 더 눌러야 한다.
    /// 지우려고 고른 카드가 이미 눈앞에 있는데 다시 겨누게 할 이유가 없다.
    private func startSelecting(with post: Post) {
        withAnimation(.spring(response: 0.35)) {
            selectedPosts = [post.persistentModelID]
            mode = .selecting
        }
    }

    /// 더 보기 메뉴의 「선택」 으로 들어온다.
    ///
    /// 카드를 꾹 눌러 들어오는 쪽과 달리 빈손으로 시작한다 — 누른 카드가 없기 때문이다.
    private func startDeleteSelection() {
        startSelection()
    }

    /// 상단 􀈂 로 들어온다. 내보내려고 들어가는 지름길이다.
    ///
    /// 꾹 눌러 들어오는 쪽과 달리 **빈손으로 시작한다.**
    /// 누른 카드가 따로 없기도 하고, 내보내기는 「무엇을 넣을지 고르는 일」 자체가 목적이라
    /// 한 장을 먼저 집어 주면 고른 적 없는 것이 섞인다.
    private func startExportSelection() {
        startSelection()
    }

    /// 고르기를 연다. 어느 길로 들어오든 같은 자리다.
    private func startSelection() {
        withAnimation(.spring(response: 0.35)) {
            selectedPosts = []
            mode = .selecting
        }
    }

    private func exitSelection() {
        withAnimation(.spring()) {
            mode = .browsing
            profileCandidatePost = nil
            selectedPosts = []
        }
    }

    private func delete(_ post: Post) {
        modelContext.delete(post)
        postPendingDelete = nil
    }

    /// 골라 둔 그림을 한꺼번에 지운다.
    ///
    /// 식별자로 들고 있으므로 모델을 다시 찾아와 지운다.
    /// 찾지 못한 것은 그냥 넘긴다 — 고르는 사이에 다른 경로로 이미 지워졌다는 뜻이라
    /// 여기서 할 일이 남아 있지 않다.
    ///
    /// 한 장씩 지울 때와 달리 여기서 바로 저장한다.
    /// 여러 장이 한 번에 빠지는 큰 변화라, 자동 저장을 기다리는 사이 앱이 꺼지면
    /// 지운 줄 알았던 그림이 통째로 돌아와 있다.
    private func deleteSelected() {
        for id in selectedPosts {
            guard let post = modelContext.registeredModel(for: id) as Post? else { continue }
            modelContext.delete(post)
        }
        try? modelContext.save()
        exitSelection()
    }
}

#Preview {
    GalleryPage()
        .modelContainer(LocalDataStore.makePreviewContainer())
}
