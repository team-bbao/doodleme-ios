//
//  GalleryPage.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/5/26.
//

import SwiftUI
import SwiftData

struct GalleryPage: View {

    // 정렬자를 주지 않으면 SwiftData 는 순서를 보장하지 않는다. 항상 최신순.
    @Query(sort: \Post.createdAt, order: .reverse) private var allPosts: [Post]
    @Query(filter: #Predicate<Post> { $0.isProfile }) private var profilePosts: [Post]

    private var profilePost: Post? { profilePosts.first }

    @Environment(\.modelContext) private var modelContext

    @State private var segmentedBar: Int = 0
    @State private var selectedTab: Bool = false
    @AppStorage("userName") private var inputName = ""


    @State private var selectedPostIDs: Set<PersistentIdentifier> = []
    @State private var showActionDialog = false
    @State private var selectedPost: Post? = nil
    @State private var isSelectingProfile = false
    @State private var profileCandidatePost: Post? = nil
    @State private var showProfileEditPopup = false
    @State private var confettiTrigger = 0
    @State private var showReceivePopup = false

    /// 화면을 덮는 오버레이가 하나라도 떠 있으면 툴바·탭바를 숨긴다.
    private var isOverlayShowing: Bool {
        selectedPost != nil || showActionDialog || showReceivePopup
    }

    private func closeReceivePopup() {
        withAnimation(.spring()) { showReceivePopup = false }
    }

    /// 액션 시트의 "프로필로 설정"은 한 장만 골랐을 때만 뜻이 통한다.
    private var singleSelectedPost: Post? {
        guard selectedPostIDs.count == 1 else { return nil }
        return allPosts.first { selectedPostIDs.contains($0.persistentModelID) }
    }

    var body: some View {
        NavigationStack{
            ZStack {
                GeometryReader { proxy in
                    Image(.papertype1)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width)
                        .clipped()
                        .ignoresSafeArea()
                }

                VStack {
                    VStack {
                        ZStack{
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
                                        withAnimation(.spring()) { isSelectingProfile = true }
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
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    withAnimation(.spring()) { showReceivePopup = true }
                                } label: {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                }
                                .accessibilityLabel("가까운 친구에게 그림 받기")
                            }
                            ToolbarItem(placement: .topBarTrailing){
                                Button(selectedTab ? "취소" : "편집") {
                                    selectedTab.toggle()
                                    if !selectedTab {
                                        selectedPostIDs.removeAll()
                                    }
                                }
                            }
                            // ToolbarItem(placement: .topBarLeading) {
                            //     Button("테스트+") {
                            //         let testPost = Post(lines: [], text: "테스트 by others", isMine: false)
                            //         modelContext.insert(testPost)
                            //     }
                            //     .foregroundStyle(.orange)
                            // }
                            if isSelectingProfile {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button("취소") {
                                        withAnimation(.spring()) {
                                            isSelectingProfile = false
                                            profileCandidatePost = nil
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 140)

                    PostGridView(
                        selectedPostIDs: $selectedPostIDs,
                        segmentedBar: $segmentedBar,
                        selectedTab: $selectedTab,
                        showActionDialog: $showActionDialog,
                        selectedPost: $selectedPost,
                        isSelectingProfile: $isSelectingProfile,
                        profileCandidatePost: $profileCandidatePost
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
                                withAnimation {
                                    self.selectedPost = nil
                                }
                            }

                        PostDetailView(post: selectedPost)
                    }
                }

                // 커스텀 바텀 액션 시트
                if showActionDialog {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring()) {
                                showActionDialog = false
                                selectedPostIDs.removeAll()
                                selectedTab = false
                            }
                        }

                    VStack {
                        Spacer()
                        VStack(spacing: 0) {
                            HStack(spacing: 24) {
                                Button {
                                    modelContext.setProfilePost(singleSelectedPost)
                                    confettiTrigger += 1
                                    selectedPostIDs.removeAll()
                                    selectedTab = false
                                    withAnimation(.spring()) { showActionDialog = false }
                                } label: {
                                    Text("프로필로 설정")
                                        .padding(.horizontal, 12)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .font(.body)
                                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 30))
                                        .foregroundStyle(.white)
                                }
                                .disabled(singleSelectedPost == nil)
                                .opacity(singleSelectedPost == nil ? 0.4 : 1)

                                Button(role: .destructive) {
                                    for post in allPosts where selectedPostIDs.contains(post.persistentModelID) {
                                        modelContext.delete(post)
                                    }
                                    selectedPostIDs.removeAll()
                                    selectedTab = false
                                    withAnimation(.spring()) { showActionDialog = false }
                                } label: {
                                    Text("삭제")
                                        .padding(.horizontal, 12)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .font(.body)
                                        .foregroundStyle(.red)
                                        .background(.ultraThinMaterial.opacity(0.9), in: RoundedRectangle(cornerRadius: 30))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)

                            Button {
                                selectedPostIDs.removeAll()
                                selectedTab = false
                                withAnimation(.spring()) { showActionDialog = false }
                            } label: {
                                Text("취소")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.black)
                                    .background(.timeColor1.opacity(0.6), in: RoundedRectangle(cornerRadius: 30))
                                    .padding(.top, 10)
                                    .padding(10)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                        .background(.white, in: RoundedRectangle(cornerRadius: 30))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                        .padding(.top, 30)
                        .padding(30)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // 프로필 설정 확인 팝업
                if let candidate = profileCandidatePost {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring()) { profileCandidatePost = nil }
                        }

                    VStack(spacing: 20) {
                        DoodleImageView(drawingData: candidate.drawingData, contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .background(.white)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(.accent.opacity(0.3), lineWidth: 1)
                        }
                        //                        .shadow(radius: 4)

                        Text("프로필로 설정하시겠습니까?")
                            .font(.headline)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 24) {
                            Button("예") {
                                modelContext.setProfilePost(candidate)
                                confettiTrigger += 1
                                withAnimation(.spring()) {
                                    profileCandidatePost = nil
                                    isSelectingProfile = false
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
                    .padding(24)
                    .background(.white, in: RoundedRectangle(cornerRadius: 30))
                    .padding(.horizontal, 40)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }

                // 프로필 편집 팝업 (기존 프로필 탭 시)
                if showProfileEditPopup {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring()) { showProfileEditPopup = false }
                        }

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
                                    isSelectingProfile = true
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
                            .background(
                                .gray.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 30)
                            )
                        }
                    }
                    .padding(50)
                    .background(.white, in: RoundedRectangle(cornerRadius: 30))
                    .padding(.horizontal, 40)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }

                // 그림 받기 팝업
                if showReceivePopup {
                    DoodlePopup(onBackgroundTap: closeReceivePopup) {
                        NearbySharingPopup(onClose: closeReceivePopup)
                    }
                }
            }
            .toolbarVisibility(isOverlayShowing ? .hidden : .visible, for: .tabBar, .navigationBar)
            .ignoresSafeArea()
        }
    }
}

#Preview {
    GalleryPage()
        .modelContainer(LocalDataStore.makePreviewContainer())
}
