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
    @State private var confettiTrigger = 0

    private var isChoosingProfile: Bool { mode == .choosingProfile }

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

                if showDeleteConfirm {
                    deleteConfirmPopup
                }
            }
            .toolbar { toolbarContent }
            .toolbarVisibility(isOverlayShowing ? .hidden : .visible, for: .tabBar, .navigationBar)
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
                        .scaledToFill()
                        .onTapGesture {
                            withAnimation(.spring()) { mode = .choosingProfile }
                        }
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.1), radius: 3, x: 2, y: 2)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "pencil")
                    .foregroundStyle(.gray)
                    .padding(6)
                    .background(Circle().fill(.white.opacity(0.6)))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 1, y: 1)
                    .offset(x: 5, y: 5)
            }
            .overlay { ConfettiBurst(trigger: confettiTrigger) }
            .offset(y: 5)

            ProfileNameView(profileName: $inputName)
                .padding(.bottom, 15)

            CustomSegmentedControl(
                selection: $segmentedBar,
                titles: ["너가 그린", "내가 그린"]
            )
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
                // 버튼 자리에서 위아래로 펼쳐진다.
                Menu {
                    Button {
                        withAnimation(.spring()) { mode = .choosingProfile }
                    } label: {
                        Label("프로필", systemImage: "person.crop.circle")
                    }

                    Button(role: .destructive) {
                        withAnimation(.spring()) { mode = .deleting }
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                } label: {
                    Text("선택")
                }
                // 메뉴가 위로 열려도 프로필 → 삭제 순서를 유지한다.
                .menuOrder(.fixed)

            case .choosingProfile:
                EmptyView()

            case .deleting:
                Button(selectedPostIDs.isEmpty ? "삭제" : "삭제 \(selectedPostIDs.count)") {
                    withAnimation(.spring()) { showDeleteConfirm = true }
                }
                .disabled(selectedPostIDs.isEmpty)
                .tint(.red)
            }
        }
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
