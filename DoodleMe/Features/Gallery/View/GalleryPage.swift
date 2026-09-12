//
//  GalleryPage.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/5/26.
//

import SwiftData
import SwiftUI

struct GalleryPage: View {

    @Query(filter: #Predicate<Post> { $0.isProfile }) private var profilePosts: [Post]

    /// 남이 나를 그려 준 것들. 「나를 그린」 묶음과 같은 조건이라 그리드와 늘 같은 것을 본다.
    ///
    /// 내보내기가 이것을 통째로 가져간다 — 고르는 단계 없이 받은 것을 전부 카드로 만든다.
    @Query(filter: #Predicate<Post> { !$0.isMine },
           sort: \Post.createdAt, order: .reverse) private var receivedPosts: [Post]

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
    @State private var selectionPurpose: GallerySelectionPurpose = .delete
    /// 고른 그림들을 카드로 만들어 보여 줄지.
    @State private var showExportPreview = false
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
    private static let contentInset: CGFloat = 20
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
                Text("갤러리")
                    .font(.system(size: 34, weight: .bold))
                    .kerning(0.4)
                    .foregroundStyle(Color.doodleTitle)
                    .padding(.leading, Self.contentInset)
                    .padding(.top, Self.titleTopInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)

                // 정렬·공유받기. 제목과 같은 높이(y=70)의 오른쪽 끝에 나란히 뜬다.
                //
                // 화면을 덮는 것이 떠 있으면 제목과 함께 물러난다.
                if !isOverlayShowing {
                    HStack(spacing: Self.topButtonSpacing) {
                        if canExport { exportButton }
                        sortMenu
                        receiveButton
                    }
                    .padding(.top, Self.titleTopInset)
                    .padding(.trailing, Self.contentInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }

                // 프로필 원과 이름. 고르는 중에도 밝게 남지만 누를 수는 없다.
                // 지금 고르는 대상은 카드이고, 프로필은 그 결과가 놓일 자리일 뿐이다.
                profileBlock
                    .padding(.top, Self.headerTopInset)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                    .padding(.horizontal, Self.contentInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(!isPickingProfile)

                // 세그먼트와 그리드.
                //
                // 세그먼트가 헤더가 아니라 여기 있는 이유가 있다.
                // 프로필로 쓸 그림은 받은 것 중에도, 내가 그린 것 중에도 있어서
                // 고르는 동안에도 두 섹션을 오갈 수 있어야 한다.
                VStack(spacing: 0) {
                    // Figma `iPhone 17 - 12` 의 막대.
                    // 트랙이 불투명한 흰색이라, 뒤에 어두운 막이 깔려도 배어 나오지 않는다.
                    GallerySegmentedControl(selection: $segmentedBar)
                        .padding(.bottom, 20)

                    PostGridView(
                        mode: mode,
                        segmentedBar: $segmentedBar,
                        sortOrder: currentSortOrder,
                        selectedPost: $selectedPost,
                        profileCandidatePost: $profileCandidatePost,
                        postPendingDelete: $postPendingDelete,
                        selectedPosts: $selectedPosts,
                        onShare: { sharingPost = $0 },
                        onStartSelecting: { startSelecting(with: $0) },
                        postToShow: $postToShow,
                        onEmptyAreaTap: emptyAreaTapAction
                    )
                }
                .padding(.horizontal, Self.contentInset)
                .padding(.top, headerHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

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

                // 카드 확대 상세 뷰
                if let selectedPost {
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

                        PostDetailView(post: selectedPost) {
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
            .ignoresSafeArea()
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

    /// 고른 그림으로 만들 카드들.
    ///
    /// **한 장이면 26번, 두 장부터 27번·28번이다.**
    /// 한 장을 격자에 덩그러니 놓으면 다섯 칸이 비고, 제목도 「사람들이 그린」 이라
    /// 한 사람이 그린 것에는 말이 맞지 않는다.
    ///
    /// 여러 장이면 그림 격자를 앞에, 한마디 말풍선을 뒤에 놓는다.
    /// 넘치면 버리지 않고 페이지를 늘린다 —
    /// 인스타그램 캐러셀이 한 게시물에 20장까지 받으므로 그대로 올릴 수 있고,
    /// 한 장에 우겨넣어 그림이 알아볼 수 없게 작아지는 것보다 낫다.
    private var exportPages: [ExportPage] {
        let posts = selectedPosts
            .compactMap { modelContext.registeredModel(for: $0) as Post? }
            .sorted { $0.createdAt > $1.createdAt }
        let name = inputName.isEmpty ? "나" : inputName

        guard posts.count > 1 else {
            guard let only = posts.first else { return [] }
            return [ExportPage(id: 0) { ExportSinglePostCard(post: only, myName: name) }]
        }

        var pages: [ExportPage] = []
        for slice in posts.chunked(by: ExportDrawingsCard.perPage) {
            pages.append(ExportPage(id: pages.count) {
                ExportDrawingsCard(posts: slice, myName: name)
            })
        }
        // 그림 뒤에 한마디를 붙인다. 한마디가 하나도 없으면 `paginate` 가 빈 배열을 주므로
        // 말풍선 장 자체가 생기지 않는다.
        for slice in ExportQuotesCard.paginate(posts) {
            pages.append(ExportPage(id: pages.count) {
                ExportQuotesCard(posts: slice, myName: name)
            })
        }
        return pages
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

            // 한 장도 고르지 않았으면 할 일이 없다.
            //
            // 색을 직접 지정하면 시스템이 비활성일 때 걸어 주는 흐림이 덮인다.
            // 눌리지도 않으면서 빨갛게 서 있어, 눌러 보고 나서야 안 된다는 걸 알게 된다.
            // 그래서 흐림도 직접 준다.
            //
            // 들어온 길에 따라 하나만 선다. 둘 다 세우면 버튼이 넷이 된다.
            switch selectionPurpose {
            case .delete:
                Button("삭제") { isConfirmingBulkDelete = true }
                    .foregroundStyle(selectedPosts.isEmpty ? Color.doodleMuted : .red)
                    .disabled(selectedPosts.isEmpty)
            case .export:
                Button("내보내기") { showExportPreview = true }
                    .foregroundStyle(selectedPosts.isEmpty ? Color.doodleMuted : Color.doodlePrimary)
                    .disabled(selectedPosts.isEmpty)
            }
        }
        .font(.system(size: 17, weight: .semibold))
        .padding(.horizontal, 24)
        .frame(height: DoodleMetrics.buttonSide + 12)
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
        .frame(maxWidth: Self.selectionBarMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Self.contentInset)
        .padding(.bottom, Self.selectionBarBottomInset)
    }

    /// 선택 바가 아무리 넓어도 이보다 넓어지지 않는다.
    /// 아이폰(402 - 좌우 20)보다 조금 여유를 둔 값이다.
    private static let selectionBarMaxWidth: CGFloat = 440

    /// 선택 바가 화면 아래에서 떨어져 있는 정도.
    /// 탭바가 서 있던 자리와 같은 높이라 홈 인디케이터를 피한다.
    private static let selectionBarBottomInset: CGFloat = 34

    // MARK: - 상단

    /// 프로필 원과 이름. 세그먼트는 어두운 레이어 위에 있어야 해서 본문 쪽에 있다.
    private var profileBlock: some View {
        // 간격을 기본값에 맡기지 않는다.
        // 기본 간격이 이름의 위 여백에 더해져, 원과 이름 사이가 Figma 보다 벌어졌다.
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .foregroundStyle(.white)

                // 사진 자체는 누를 수 없다. 프로필을 바꾸는 문은 연필 뱃지 하나뿐이다.
                if let profilePost {
                    DoodleImageView(drawingData: profilePost.drawingData, contentMode: .fill)
                } else {
                    DefaultDoodleImage()
                        // 원을 꽉 채우지 않고 지름의 80% 크기로 가운데 놓는다.
                        .frame(width: Self.profileDiameter * 0.8,
                               height: Self.profileDiameter * 0.8)
                }
            }
            .frame(width: Self.profileDiameter, height: Self.profileDiameter)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.1), radius: 3, x: 2, y: 2)
            .overlay(alignment: .bottomTrailing) { profileEditBadge }
            .overlay { ConfettiBurst(trigger: confettiTrigger) }
            .offset(y: 5)

            ProfileNameView(profileName: $inputName)
                // 이 여백이 곧 세그먼트가 놓이는 높이를 정한다.
                // 124(시작) + 97(원) + 12.5(이름 위) + 24(이름) + 36.5 = 294 — Figma `222:1199` 의 y.
                .padding(.bottom, 36.5)
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
                .frame(width: Self.profileBadgeDiameter, height: Self.profileBadgeDiameter)
                .background(Circle().fill(Color.doodlePrimary))
                .shadow(color: .black.opacity(0.2), radius: 2, y: 3)
                .frame(width: Self.profileBadgeTapDiameter, height: Self.profileBadgeTapDiameter)
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
    private var sortMenu: some View {
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
        } label: {
            // Figma 글리프 상자가 26x24. 공유받기와 같은 20 으로 둔다.
            Image(systemName: "list.bullet")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.doodlePrimary)
                .frame(width: DoodleMetrics.buttonSide, height: DoodleMetrics.buttonSide)
                // Figma: 흰색 80% · 그림자 0 4 15 검정 5%. SwiftUI 반경은 blur 의 절반.
                .background(.white.opacity(0.8), in: Circle())
                .shadow(color: .black.opacity(0.05), radius: 7.5, y: 4)
        }
        .accessibilityLabel("정렬 방법")
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
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.doodleOnDarkButton)
                .frame(width: DoodleMetrics.buttonSide, height: DoodleMetrics.buttonSide)
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
            startExportSelection()
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.doodlePrimary)
                .frame(width: DoodleMetrics.buttonSide, height: DoodleMetrics.buttonSide)
                .background(.white.opacity(0.8), in: Circle())
                .shadow(color: .black.opacity(0.05), radius: 7.5, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("받은 그림 내보내기")
    }

    /// 내보낼 것이 있는지.
    ///
    /// 「나를 그린」 에서만 낸다. Figma `iPhone 17 - 27 / 28` 의 제목이
    /// 「**사람들이** 그린 / ○○의 첫인상」 이라 남이 나를 그려 준 것에만 뜻이 맞는다.
    /// 한 장도 없으면 눌러도 빈 종이만 나오므로 버튼 자체를 내지 않는다.
    private var canExport: Bool {
        GallerySection(rawValue: segmentedBar) == .receivedFromOthers && !receivedPosts.isEmpty
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
            selectionPurpose = .delete
            mode = .selecting
        }
    }

    /// 상단 􀈂 로 들어온다. 내보낼 그림을 고르는 자리다.
    ///
    /// 꾹 눌러 들어오는 쪽과 달리 **빈손으로 시작한다.**
    /// 누른 카드가 따로 없기도 하고, 내보내기는 「무엇을 넣을지 고르는 일」 자체가 목적이라
    /// 한 장을 먼저 집어 주면 고른 적 없는 것이 섞인다.
    private func startExportSelection() {
        withAnimation(.spring(response: 0.35)) {
            selectedPosts = []
            selectionPurpose = .export
            mode = .selecting
        }
    }

    private func exitSelection() {
        withAnimation(.spring()) {
            mode = .browsing
            profileCandidatePost = nil
            selectionPurpose = .delete
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
