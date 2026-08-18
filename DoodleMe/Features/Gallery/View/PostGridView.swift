//
//  PostGridView.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/11/26.
//

import SwiftData
import SwiftUI

struct PostGridView: View {

    // 필터·정렬을 SwiftData 에 맡긴다. 메모리에서 filter 하지 않으므로 순서도 항상 최신순으로 보장된다.
    @Query(filter: #Predicate<Post> { $0.isMine },
           sort: \Post.createdAt, order: .reverse) private var postsByMe: [Post]
    @Query(filter: #Predicate<Post> { !$0.isMine },
           sort: \Post.createdAt, order: .reverse) private var postsByOthers: [Post]
    /// 프로필로 고를 수 있는 후보(이미 프로필인 그림은 제외).
    @Query(filter: #Predicate<Post> { !$0.isProfile },
           sort: \Post.createdAt, order: .reverse) private var profileCandidates: [Post]

    let mode: GalleryMode
    @Binding var selectedPostIDs: Set<PersistentIdentifier>
    @Binding var segmentedBar: Int
    @Binding var selectedPost: Post?
    @Binding var profileCandidatePost: Post?

    /// 카드를 꾹 눌러 고른 동작. 화면 전환과 팝업은 `GalleryPage` 가 맡는다.
    var onShare: ((Post) -> Void)?
    var onRequestDelete: ((Post) -> Void)?

    /// 카드가 아닌 빈 곳을 눌렀을 때. 프로필 고르기에서 빠져나오는 데 쓴다.
    ///
    /// 그리드는 `ScrollView` 라 화면 아래쪽 대부분을 차지한다.
    /// 뒤에 깔린 레이어가 탭을 받을 수 없으므로 여기서 직접 받아 넘겨준다.
    var onEmptyAreaTap: (() -> Void)?

    /// 프로필을 고를 때는 세그먼트와 무관하게 후보 전체를 보여준다.
    private var currentPosts: [Post] {
        mode == .choosingProfile
            ? profileCandidates
            : (segmentedBar == 1 ? postsByMe : postsByOthers)
    }

    /// 비어 있을 때 보여줄 문구. 어느 탭인지에 따라 할 일이 다르다.
    private var emptyMessage: String {
        if mode == .choosingProfile { return "고를 수 있는 그림이 없어요" }
        // 0 = 너가 그린(받은 것), 1 = 내가 그린
        return segmentedBar == 1 ? "친구의 얼굴을 그려보세요" : "친구가 그린 그림을 받아보세요"
    }

    private let columns = [
        GridItem(.flexible(), spacing: 30),
        GridItem(.flexible(), spacing: 30)
    ]

    var body: some View {
        if currentPosts.isEmpty {
            Text(emptyMessage)
                .foregroundStyle(.colorGray)
                .padding(.top, 70)
                .fontWeight(.bold)
                .font(.system(size: 25))
                .opacity(0.4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .contentShape(Rectangle())
                .onTapGesture { onEmptyAreaTap?() }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(currentPosts) { post in
                        card(for: post)
                    }
                }
                // 마지막 줄 아래에도 누를 수 있는 여백을 남긴다.
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, minHeight: 0, alignment: .top)
            }
            // 카드보다 바깥쪽 제스처라, 카드 탭은 카드가 먼저 가져간다.
            .contentShape(Rectangle())
            .onTapGesture { onEmptyAreaTap?() }
        }
    }

    private func card(for post: Post) -> some View {
        let selected = isSelected(post)

        return Image(.memoFront)
            .resizable()
            .scaledToFill()
            .frame(height: 170)
            .clipped()
            .overlay {
                DoodleImageView(drawingData: post.drawingData)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            // 고른 카드는 어둡게 덮어서 한눈에 구분되게 한다.
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(selected ? 0.4 : 0))
            }
            // 여러 장을 골라야 하는 삭제에서만 선택 표시를 띄운다.
            // 프로필은 누르는 즉시 확인 팝업이 떠서 체크 상태를 볼 일이 없다.
            .overlay(alignment: .topTrailing) {
                if mode == .deleting {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        // 어두워진 카드 위에서도 보이도록 흰색을 쓴다.
                        .foregroundStyle(selected ? Color.white : .gray)
                        .padding(8)
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            .animation(.easeInOut(duration: 0.15), value: selected)
            .onTapGesture { handleTap(on: post) }
            .accessibilityAddTraits(selected ? [.isSelected] : [])
            .contextMenu { cardMenu(for: post) }
    }

    /// 카드를 꾹 눌렀을 때 뜨는 메뉴.
    ///
    /// 고르는 중에는 비워 둔다. 이미 고르는 동작을 하고 있는데
    /// 한 장짜리 메뉴가 끼어들면 무엇에 적용되는지 헷갈린다.
    @ViewBuilder
    private func cardMenu(for post: Post) -> some View {
        if mode == .browsing {
            Button {
                withAnimation(.spring()) { profileCandidatePost = post }
            } label: {
                Label("프로필 사진 설정", systemImage: "person.crop.circle")
            }

            Button {
                onShare?(post)
            } label: {
                Label("그림 공유하기", systemImage: "airplay.audio")
            }

            Button(role: .destructive) {
                onRequestDelete?(post)
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    private func isSelected(_ post: Post) -> Bool {
        switch mode {
        case .browsing:
            false
        case .choosingProfile:
            profileCandidatePost?.persistentModelID == post.persistentModelID
        case .deleting:
            selectedPostIDs.contains(post.persistentModelID)
        }
    }

    private func handleTap(on post: Post) {
        switch mode {
        case .browsing:
            selectedPost = post

        case .choosingProfile:
            // 한 장만 고른다. 확인 팝업은 GalleryPage 가 띄운다.
            withAnimation(.spring()) { profileCandidatePost = post }

        case .deleting:
            // 여러 장을 골랐다 뺐다 할 수 있다.
            if selectedPostIDs.contains(post.persistentModelID) {
                selectedPostIDs.remove(post.persistentModelID)
            } else {
                selectedPostIDs.insert(post.persistentModelID)
            }
        }
    }
}

#Preview {
    PostGridView(
        mode: .browsing,
        selectedPostIDs: .constant([]),
        segmentedBar: .constant(0),
        selectedPost: .constant(nil),
        profileCandidatePost: .constant(nil)
    )
    .modelContainer(LocalDataStore.makePreviewContainer())
}
