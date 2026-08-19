//
//  GalleryPage.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/5/26.
//

import SwiftData
import SwiftUI

struct GalleryPage: View {
    /// 탭바를 보여줄지. 그림을 펼쳐 보는 동안에는 자리를 비켜준다.
    @Binding var showsTabBar: Bool


    @Query(filter: #Predicate<Post> { $0.isProfile }) private var profilePosts: [Post]

    private var profilePost: Post? { profilePosts.first }

    @Environment(\.modelContext) private var modelContext

    /// 지금 보고 있는 섹션. 그리기·공유 화면이 저장을 마치고 여기에 적어 둘 수 있어야 해서
    /// `@State` 가 아니라 저장소를 통해 오간다.
    @AppStorage(GallerySection.storageKey) private var segmentedBar = GallerySection.receivedFromOthers.rawValue
    @AppStorage("userName") private var inputName = ""

    @State private var mode: GalleryMode = .browsing
    /// 지우려고 확인 팝업을 띄운 그림. 한 번에 한 장만 지운다.
    @State private var postPendingDelete: Post?
    @State private var selectedPost: Post?
    @State private var profileCandidatePost: Post?
    @State private var showProfileEditPopup = false
    @State private var showSharingScreen = false
    /// 카드를 꾹 눌러 "그림 공유하기" 를 고른 경우. 이 그림을 들고 멀티피어 화면을 연다.
    @State private var sharingPost: Post?
    /// 헤더 높이. 그리드를 헤더 아래에 붙이는 데 쓴다.
    @State private var headerHeight: CGFloat = 0
    @State private var confettiTrigger = 0

    private var isChoosingProfile: Bool { mode == .choosingProfile }

    // Figma `iPhone 17 - 1` 기준 치수
    /// 프로필 원 지름
    private static let profileDiameter: CGFloat = 110
    /// 연필 뱃지 지름
    private static let profileBadgeDiameter: CGFloat = 25
    /// 세그먼트 컨트롤 좌우 여백. 바깥 VStack 이 이미 16 을 주므로 그만큼 뺀 값을 더한다.
    private static let segmentExtraInset: CGFloat = 12
    /// 프로필 원이 시작하는 높이.
    private static let headerTopInset: CGFloat = 140

    /// 프로필 고르기에는 취소 버튼이 없다. 카드가 아닌 빈 곳을 누르면 빠져나온다.
    private var emptyAreaTapAction: (() -> Void)? {
        isChoosingProfile ? { exitSelection() } : nil
    }

    /// 화면을 덮는 것이 떠 있으면 툴바·탭바를 숨긴다.
    ///
    /// `alert` 는 스스로 화면을 덮으므로 여기 넣지 않는다.
    /// 넣어 두면 확인창이 뜰 때마다 탭바가 사라졌다 돌아오며 화면이 흔들린다.
    private var isOverlayShowing: Bool {
        selectedPost != nil || isChoosingProfile
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                // 프로필 원과 이름은 어두운 레이어 **아래**에 둔다.
                // 위에 두고 opacity/colorMultiply 로 낮추면 흰 원이 밝게 남는다.
                // 특히 글래스 효과는 시스템이 따로 그려서 색 보정이 먹지 않는다.
                // 같은 합성을 거치게 해야 배경과 똑같이 어두워진다.
                profileBlock
                    .padding(.top, Self.headerTopInset)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(!isChoosingProfile)

                // 프로필을 고르는 동안에는 그림 말고 다 어둡게 덮는다.
                // 취소 버튼이 없으므로 어두운 곳을 눌러 빠져나온다.
                if isChoosingProfile {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { exitSelection() }
                        .transition(.opacity)
                }

                // 세그먼트와 그리드는 어두운 레이어 **위**에 남아 밝게 보인다.
                //
                // 세그먼트가 헤더가 아니라 여기 있는 이유가 있다.
                // 프로필로 쓸 그림은 받은 것 중에도, 내가 그린 것 중에도 있다.
                // 고르는 동안에도 두 섹션을 오갈 수 있어야 해서 어두운 레이어 위로 올렸다.
                VStack(spacing: 0) {
                    // 시스템 세그먼트를 쓴다. 접근성·Dynamic Type·키보드 이동이 딸려 온다.
                    Picker("보기", selection: $segmentedBar) {
                        ForEach(GallerySection.allCases, id: \.self) { section in
                            Text(section.title).tag(section.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal, Self.segmentExtraInset)
                    .padding(.bottom, 20)

                    PostGridView(
                        mode: mode,
                        segmentedBar: $segmentedBar,
                        selectedPost: $selectedPost,
                        profileCandidatePost: $profileCandidatePost,
                        postPendingDelete: $postPendingDelete,
                        onShare: { sharingPost = $0 },
                        onEmptyAreaTap: emptyAreaTapAction
                    )
                }
                .padding(.horizontal)
                .padding(.top, headerHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

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
                                withAnimation { self.selectedPost = nil }
                            }

                        PostDetailView(post: selectedPost)
                    }
                }
            }
            .toolbar { toolbarContent }
            .toolbarVisibility(isOverlayShowing ? .hidden : .visible, for: .navigationBar)
            // 기본 탭바는 접고 직접 그린 탭바를 쓴다.
            .toolbarVisibility(.hidden, for: .tabBar)
            // 그림을 펼쳐 보는 동안에는 탭바가 자리를 비켜준다.
            .onChange(of: isOverlayShowing, initial: true) { showsTabBar = !isOverlayShowing }
            .ignoresSafeArea()
            // 보낼 그림 없이 열면 받기 전용으로 동작한다.
            .fullScreenCover(isPresented: $showSharingScreen) {
                NearbySharingScreen { showSharingScreen = false }
            }
            // 카드를 꾹 눌러 고른 한 장을 들고 여는 경우.
            .fullScreenCover(item: $sharingPost) { post in
                NearbySharingScreen(post: post) { sharingPost = nil }
            }
            // 확인을 묻는 자리는 모두 `alert` 로 통일한다.
            //
            // `confirmationDialog` 는 누른 자리에 앵커되어 꼬리가 달린 채 뜬다.
            // 어느 카드인지는 알려주지만 뜨는 자리가 그때그때 달라 화면이 어수선하다.
            // `alert` 는 언제나 가운데에 꼬리 없이 떠서 세 확인창이 같은 얼굴을 갖는다.
            //
            // 파괴적 동작이 빨갛게, 취소가 제자리에 오는 배치는 시스템이 알아서 잡아준다.
            .alert(
                "이 그림을 프로필로 설정할까요?",
                isPresented: isProfileCandidatePresented
            ) {
                Button("프로필로 설정") { confirmProfile() }
                Button("취소", role: .cancel) { profileCandidatePost = nil }
            }
            .alert("프로필 사진", isPresented: $showProfileEditPopup) {
                Button("다른 그림으로 변경") {
                    withAnimation(.spring()) { mode = .choosingProfile }
                }
                Button("프로필 사진 삭제", role: .destructive) {
                    modelContext.setProfilePost(nil)
                }
                Button("취소", role: .cancel) { }
            }
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
        }
    }

    // MARK: - 상단

    /// 프로필 원과 이름. 세그먼트는 어두운 레이어 위에 있어야 해서 본문 쪽에 있다.
    private var profileBlock: some View {
        VStack {
            ZStack {
                Circle()
                    .foregroundStyle(.white)

                if let profilePost {
                    DoodleImageView(drawingData: profilePost.drawingData, contentMode: .fill)
                        .onTapGesture {
                            withAnimation(.spring()) { showProfileEditPopup = true }
                        }
                } else {
                    DefaultDoodleImage()
                        // 원을 꽉 채우지 않고 지름의 80% 크기로 가운데 놓는다.
                        .frame(width: Self.profileDiameter * 0.8,
                               height: Self.profileDiameter * 0.8)
                        .onTapGesture {
                            withAnimation(.spring()) { mode = .choosingProfile }
                        }
                }
            }
            .frame(width: Self.profileDiameter, height: Self.profileDiameter)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.1), radius: 3, x: 2, y: 2)
            .overlay(alignment: .bottomTrailing) {
                // Figma: #424242 원 + 흰 연필, 그림자 y3 blur3 black 20%
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: Self.profileBadgeDiameter, height: Self.profileBadgeDiameter)
                    .background(Circle().fill(Color.doodlePrimary))
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 3)
                    .offset(x: -4)
            }
            .overlay { ConfettiBurst(trigger: confettiTrigger) }
            .offset(y: 5)

            ProfileNameView(profileName: $inputName)
                .padding(.bottom, 15)
        }
    }

    // MARK: - 툴바

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            switch mode {
            case .browsing:
                // 프로필 설정과 삭제는 카드를 꾹 눌러서 하므로 메뉴가 필요 없어졌다.
                // 남은 건 공유받기 하나뿐이라 바로 여는 버튼으로 둔다.
                Button {
                    showSharingScreen = true
                } label: {
                    Image(systemName: "airplay.audio")
                }
                .accessibilityLabel("그림 공유받기")

            // 프로필 고르기는 카드를 누르면 바로 확인 팝업이 떠서 툴바 버튼이 필요 없다.
            case .choosingProfile:
                EmptyView()
            }
        }
    }


    // MARK: - 동작

    // `confirmationDialog` 는 `Bool` 로만 여닫는데, 우리가 든 건 "무엇에 대한 확인인가" 라는 값이다.
    // 값이 있으면 떠 있고 닫히면 비우도록 이어 준다.

    private var isProfileCandidatePresented: Binding<Bool> {
        Binding(
            get: { profileCandidatePost != nil },
            set: { if !$0 { profileCandidatePost = nil } }
        )
    }

    private var isDeletePresented: Binding<Bool> {
        Binding(
            get: { postPendingDelete != nil },
            set: { if !$0 { postPendingDelete = nil } }
        )
    }

    /// 고른 그림을 프로필로 앉힌다.
    private func confirmProfile() {
        guard let candidate = profileCandidatePost else { return }
        modelContext.setProfilePost(candidate)
        confettiTrigger += 1
        profileCandidatePost = nil
        withAnimation(.spring()) { mode = .browsing }
    }

    private func exitSelection() {
        withAnimation(.spring()) {
            mode = .browsing
            profileCandidatePost = nil
        }
    }

    private func delete(_ post: Post) {
        modelContext.delete(post)
        postPendingDelete = nil
    }
}

#Preview {
    GalleryPage(showsTabBar: .constant(true))
        .modelContainer(LocalDataStore.makePreviewContainer())
}
