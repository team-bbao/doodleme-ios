//
//  GalleryPage.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/5/26.
//

import SwiftData
import SwiftUI

struct GalleryPage: View {

    // 정렬자를 주지 않으면 SwiftData 는 순서를 보장하지 않는다. 항상 최신순.
    @Query(sort: \Post.createdAt, order: .reverse) private var allPosts: [Post]
    @Query(filter: #Predicate<Post> { $0.isProfile }) private var profilePosts: [Post]

    private var profilePost: Post? { profilePosts.first }

    @Environment(\.modelContext) private var modelContext

    @State private var segmentedBar: Int = 0
    @AppStorage("userName") private var inputName = ""

    @State private var mode: GalleryMode = .browsing
    @State private var selectedPostIDs: Set<PersistentIdentifier> = []
    @State private var selectedPost: Post?
    @State private var profileCandidatePost: Post?
    @State private var showProfileEditPopup = false
    @State private var showDeleteConfirm = false
    @State private var showSelectMenu = false
    @State private var confettiTrigger = 0

    private var isChoosingProfile: Bool { mode == .choosingProfile }

    // Figma `iPhone 17 - 1` 기준 치수
    /// 프로필 원 지름
    private static let profileDiameter: CGFloat = 116
    /// 연필 뱃지 지름
    private static let profileBadgeDiameter: CGFloat = 25
    /// 세그먼트 컨트롤 좌우 여백. 바깥 VStack 이 이미 16 을 주므로 그만큼 뺀 값을 더한다.
    private static let segmentExtraInset: CGFloat = 12

    /// 프로필 고르기에는 취소 버튼이 없다. 카드가 아닌 빈 곳을 누르면 빠져나온다.
    private var emptyAreaTapAction: (() -> Void)? {
        isChoosingProfile ? { exitSelection() } : nil
    }

    /// 화면을 덮는 오버레이가 하나라도 떠 있으면 툴바·탭바를 숨긴다.
    /// 프로필을 고를 때도 그림에만 집중하도록 함께 숨긴다.
    private var isOverlayShowing: Bool {
        selectedPost != nil
            || showDeleteConfirm
            || showProfileEditPopup
            || profileCandidatePost != nil
            || isChoosingProfile
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GeometryReader { proxy in
                    Image(.papertype1)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width)
                        .clipped()
                        .ignoresSafeArea()
                }

                // 프로필을 고를 때는 그림 말고 다 어둡게 덮는다.
                // 그리드는 이 레이어보다 위에 그려지므로 카드만 밝게 남는다.
                if isChoosingProfile {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        // 취소 버튼을 없앤 대신, 어두운 곳을 누르면 빠져나온다.
                        .onTapGesture { exitSelection() }
                        .transition(.opacity)
                }

                VStack {
                    header
                        .padding(.top, 140)
                        // 헤더는 어두운 레이어 위에 있으므로 직접 흐리게 만든다.
                        .opacity(isChoosingProfile ? 0.4 : 1)
                        .allowsHitTesting(!isChoosingProfile)

                    PostGridView(
                        mode: mode,
                        selectedPostIDs: $selectedPostIDs,
                        segmentedBar: $segmentedBar,
                        selectedPost: $selectedPost,
                        profileCandidatePost: $profileCandidatePost,
                        onEmptyAreaTap: emptyAreaTapAction
                    )
                    .frame(maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.horizontal)

                // 카드 확대 상세 뷰
                if let selectedPost {
                    ZStack {
                        Color.white
                            .opacity(0.9)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation { self.selectedPost = nil }
                            }

                        PostDetailView(post: selectedPost)
                    }
                }

                if let candidate = profileCandidatePost {
                    profileConfirmPopup(candidate: candidate)
                }

                if showProfileEditPopup {
                    profileEditPopup
                }

                if showSelectMenu {
                    // 바깥을 누르면 닫힌다. 그리드 위에 있어야 탭을 가로챌 수 있다.
                    Color.clear
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { closeSelectMenu() }

                    selectMenu
                }

                if mode == .deleting {
                    selectionBar
                }

                if showDeleteConfirm {
                    deleteConfirmPopup
                }
            }
            .toolbar { toolbarContent }
            .toolbarVisibility(isOverlayShowing ? .hidden : .visible, for: .navigationBar)
            // 삭제 중에는 탭바 자리를 선택 바가 대신 쓴다.
            .toolbarVisibility(isOverlayShowing || mode == .deleting ? .hidden : .visible, for: .tabBar)
            .ignoresSafeArea()
        }
    }

    // MARK: - 상단

    private var header: some View {
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
                    Image(.profileDefault)
                        .resizable()
                        .scaledToFit()
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

            CustomSegmentedControl(
                selection: $segmentedBar,
                titles: ["너가 그린", "내가 그린"]
            )
            .padding(.horizontal, Self.segmentExtraInset)
            .padding(.bottom, 20)
        }
    }

    // MARK: - 툴바

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // 프로필 고르기는 카드를 누르면 바로 확인 팝업이 뜨고,
        // 어두운 곳을 누르면 빠져나올 수 있어서 툴바 버튼이 필요 없다.
        if mode == .deleting {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { exitSelection() }
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            switch mode {
            case .browsing:
                // 시스템 Menu 는 최소 너비가 정해져 있어 짧은 한글 라벨이면 오른쪽이 휑하다.
                // 내용에 맞는 크기로 직접 그린다(selectMenu).
                Button("선택") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showSelectMenu.toggle()
                    }
                }

            // 프로필 고르기는 팝업이, 삭제는 하단 선택 바가 대신한다.
            case .choosingProfile, .deleting:
                EmptyView()
            }
        }
    }

    // MARK: - 선택 메뉴

    /// "선택" 버튼 아래에 붙는 드롭다운. 내용에 맞는 너비로 그린다.
    private var selectMenu: some View {
        VStack(spacing: 0) {
            menuRow(title: "프로필", systemImage: "person.crop.circle") {
                mode = .choosingProfile
            }

            Divider()
                .padding(.horizontal, 12)

            menuRow(title: "삭제", systemImage: "trash", isDestructive: true) {
                mode = .deleting
            }
        }
        .frame(width: 150)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        .padding(.top, 108)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .transition(.scale(scale: 0.9, anchor: .topTrailing).combined(with: .opacity))
    }

    private func menuRow(
        title: String,
        systemImage: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.spring()) {
                showSelectMenu = false
                action()
            }
        } label: {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: systemImage)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isDestructive ? Color.red : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func closeSelectMenu() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showSelectMenu = false
        }
    }

    // MARK: - 삭제 선택 바

    /// 사진 앱 선택 모드처럼, 탭바 자리에 고른 개수와 삭제 버튼을 띄운다.
    private var selectionBar: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack(alignment: .bottom) {
                // 아래로 갈수록 짙어지는 회색.
                // 카드가 바 뒤로 스크롤돼도 글씨가 묻히지 않게 받쳐준다.
                LinearGradient(
                    colors: [.gray.opacity(0), .gray.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 180)
                .allowsHitTesting(false)

                ZStack {
                    Text(selectedPostIDs.isEmpty
                         ? "지울 그림을 골라주세요"
                         : "\(selectedPostIDs.count)장의 그림이 선택됨")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)

                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring()) { showDeleteConfirm = true }
                        } label: {
                            Image(systemName: "trash")
                                .font(.title3)
                                .foregroundStyle(selectedPostIDs.isEmpty ? .gray : .red)
                        }
                        .disabled(selectedPostIDs.isEmpty)
                        .accessibilityLabel("고른 그림 삭제")
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - 팝업

    private func profileConfirmPopup(candidate: Post) -> some View {
        DoodlePopup(cardPadding: 24, horizontalInset: 40) {
            withAnimation(.spring()) { profileCandidatePost = nil }
        } content: {
            VStack(spacing: 20) {
                DoodleImageView(drawingData: candidate.drawingData, contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .background(.white)
                    .clipShape(Circle())
                    .overlay {
                        Circle().strokeBorder(.accent.opacity(0.3), lineWidth: 1)
                    }

                Text("프로필로 설정하시겠습니까?")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                HStack(spacing: 24) {
                    Button("예") {
                        modelContext.setProfilePost(candidate)
                        confettiTrigger += 1
                        withAnimation(.spring()) {
                            profileCandidatePost = nil
                            mode = .browsing
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 30))
                    .foregroundStyle(.white)

                    Button("아니오", role: .destructive) {
                        withAnimation(.spring()) { profileCandidatePost = nil }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 30))
                }
            }
        }
    }

    private var profileEditPopup: some View {
        DoodlePopup(cardPadding: 50, horizontalInset: 40) {
            withAnimation(.spring()) { showProfileEditPopup = false }
        } content: {
            VStack(spacing: 20) {
                Text("프로필사진을 변경하시겠습니까?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 30)
                    .padding(.top, 15)

                HStack(spacing: 24) {
                    Button("예") {
                        withAnimation(.spring()) {
                            showProfileEditPopup = false
                            mode = .choosingProfile
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 30))
                    .foregroundStyle(.white)

                    Button("삭제", role: .destructive) {
                        modelContext.setProfilePost(nil)
                        withAnimation(.spring()) { showProfileEditPopup = false }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 30))
                }
            }
        }
    }

    private var deleteConfirmPopup: some View {
        DoodlePopup(cardPadding: 24, horizontalInset: 40) {
            withAnimation(.spring()) { showDeleteConfirm = false }
        } content: {
            VStack(spacing: 20) {
                Text("\(selectedPostIDs.count)장을 삭제하시겠습니까?")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("삭제한 그림은 되돌릴 수 없어요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 24) {
                    Button("취소") {
                        withAnimation(.spring()) { showDeleteConfirm = false }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 30))

                    Button("삭제", role: .destructive) {
                        deleteSelected()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 30))
                    .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - 동작

    private func exitSelection() {
        withAnimation(.spring()) {
            mode = .browsing
            selectedPostIDs.removeAll()
            profileCandidatePost = nil
        }
    }

    private func deleteSelected() {
        for post in allPosts where selectedPostIDs.contains(post.persistentModelID) {
            modelContext.delete(post)
        }
        withAnimation(.spring()) {
            showDeleteConfirm = false
            selectedPostIDs.removeAll()
            mode = .browsing
        }
    }
}

#Preview {
    GalleryPage()
        .modelContainer(LocalDataStore.makePreviewContainer())
}
