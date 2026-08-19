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

    let mode: GalleryMode
    @Binding var segmentedBar: Int
    @Binding var selectedPost: Post?
    @Binding var profileCandidatePost: Post?

    /// 지우려고 확인을 기다리는 그림. 확인창은 화면 가운데에 `GalleryPage` 가 띄운다.
    @Binding var postPendingDelete: Post?

    /// 카드를 꾹 눌러 고른 동작. 화면 전환은 `GalleryPage` 가 맡는다.
    var onShare: ((Post) -> Void)?

    /// 카드가 아닌 빈 곳을 눌렀을 때. 프로필 고르기에서 빠져나오는 데 쓴다.
    ///
    /// 그리드는 `ScrollView` 라 화면 아래쪽 대부분을 차지한다.
    /// 뒤에 깔린 레이어가 탭을 받을 수 없으므로 여기서 직접 받아 넘겨준다.
    var onEmptyAreaTap: (() -> Void)?

    /// 지금 보여줄 그림들.
    ///
    /// 프로필을 고를 때도 세그먼트를 그대로 따른다.
    /// 프로필감은 받은 것 중에도, 내가 그린 것 중에도 있어서 한쪽만 보여주면 고를 수가 없다.
    /// 이미 프로필인 한 장만 빼는데, 한 장뿐이라 정렬이 흐트러지지 않는다.
    private var currentPosts: [Post] {
        // 0 = 너가 그린(받은 것), 1 = 내가 그린
        let posts = segmentedBar == 1 ? postsByMe : postsByOthers
        return mode == .choosingProfile ? posts.filter { !$0.isProfile } : posts
    }

    /// 비어 있을 때 보여줄 문구. 무엇을 하는 중인지, 어느 탭인지에 따라 할 일이 다르다.
    private var emptyMessage: String {
        switch (mode, segmentedBar == 1) {
        case (.choosingProfile, true): "고를 수 있는 내 그림이 없어요"
        case (.choosingProfile, false): "고를 수 있는 받은 그림이 없어요"
        case (.browsing, true): "친구의 얼굴을 그려보세요"
        case (.browsing, false): "친구가 그린 그림을 받아보세요"
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 30),
        GridItem(.flexible(), spacing: 30)
    ]

    var body: some View {
        if currentPosts.isEmpty {
            // 위에 붙여 두면 카드가 놓일 자리가 아니라 헤더 바로 밑에서 뜬다.
            // 그리드가 차지할 영역 한가운데에 두어 "여기가 빈 자리" 임을 보여준다.
            Text(emptyMessage)
                .foregroundStyle(.colorGray)
                .fontWeight(.semibold)
                .font(.system(size: 20))
                .opacity(0.4)
                .multilineTextAlignment(.center)
                .padding(.bottom, 100)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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

        return paperLayer(.memoFront)
            .overlay {
                // 접힌 삼각형과 잘려나간 모서리에는 그림이 얹히지 않게 한다.
                // 마스크는 종이와 똑같은 배치를 거쳐야 접힌 자리가 정확히 맞는다.
                DoodleImageView(drawingData: post.drawingData)
                    .mask { paperLayer(.memoFrontMask) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            // 고른 카드는 어둡게 덮어서 한눈에 구분되게 한다.
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(selected ? 0.4 : 0))
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
                postPendingDelete = post
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    /// 종이와 그 마스크가 같은 배치를 쓰도록 한곳에 모아 둔다.
    /// 둘이 어긋나면 접힌 자리에 그림이 반쯤 걸친다.
    private func paperLayer(_ resource: ImageResource) -> some View {
        Image(resource)
            .resizable()
            .scaledToFill()
            .frame(height: 170)
            .clipped()
    }

    private func isSelected(_ post: Post) -> Bool {
        switch mode {
        case .browsing:
            false
        case .choosingProfile:
            profileCandidatePost?.persistentModelID == post.persistentModelID
        }
    }

    private func handleTap(on post: Post) {
        switch mode {
        case .browsing:
            selectedPost = post

        case .choosingProfile:
            // 한 장만 고른다. 확인 팝업은 GalleryPage 가 띄운다.
            withAnimation(.spring()) { profileCandidatePost = post }
        }
    }
}

#Preview {
    PostGridView(
        mode: .browsing,
        segmentedBar: .constant(0),
        selectedPost: .constant(nil),
        profileCandidatePost: .constant(nil),
        postPendingDelete: .constant(nil)
    )
    .modelContainer(LocalDataStore.makePreviewContainer())
}
