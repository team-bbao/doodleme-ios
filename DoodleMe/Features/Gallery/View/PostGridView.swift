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

    /// 카드를 늘어놓는 순서. 두 섹션에 똑같이 걸린다.
    let sortOrder: GallerySortOrder
    @Binding var selectedPost: Post?
    @Binding var profileCandidatePost: Post?

    /// 지우려고 확인을 기다리는 그림. 확인창은 화면 가운데에 `GalleryPage` 가 띄운다.
    @Binding var postPendingDelete: Post?

    /// 카드를 꾹 눌러 고른 동작. 화면 전환은 `GalleryPage` 가 맡는다.
    var onShare: ((Post) -> Void)?

    /// 보여줘야 할 그림. 값이 들어오면 그 자리로 스크롤하고 도로 비운다.
    ///
    /// 방금 받은 그림이 화면 밖에 있을 수 있다.
    /// 최신순이면 맨 앞이라 그냥 보이지만, 오래된 순이면 맨 뒤에 붙는다.
    @Binding var postToShow: Post.ID?

    /// 카드가 아닌 빈 곳을 눌렀을 때. 프로필 고르기에서 빠져나오는 데 쓴다.
    ///
    /// 그리드는 `ScrollView` 라 화면 아래쪽 대부분을 차지한다.
    /// 뒤에 깔린 레이어가 탭을 받을 수 없으므로 여기서 직접 받아 넘겨준다.
    var onEmptyAreaTap: (() -> Void)?

    /// 지금 보여줄 그림들.
    ///
    /// 프로필을 고를 때도 세그먼트를 그대로 따른다.
    /// 프로필감은 받은 것 중에도, 내가 그린 것 중에도 있어서 한쪽만 보여주면 고를 수가 없다.
    ///
    /// 무엇을 하는 중이든 있는 그림을 다 보여준다.
    /// 예전에는 고르는 동안 이미 프로필인 한 장을 빼 뒀는데,
    /// 연필을 누른 사람에게는 그림 한 장이 사라진 것으로 보였다.
    /// 이미 프로필인 것을 다시 골라 봐야 그대로일 뿐이라, 숨겨서 얻는 것도 없다.
    private var currentPosts: [Post] {
        // 0 = 너가 그린(받은 것), 1 = 내가 그린
        let posts = segmentedBar == 1 ? postsByMe : postsByOthers

        // 질의는 늘 최신순으로 받아 둔다. 오래된 순은 그 줄을 뒤집기만 하면 된다.
        //
        // 정렬 키(`createdAt`)가 같으니 뒤집어도 순서가 흐트러지지 않고,
        // 방향이 다른 질의를 한 벌 더 들 이유도 없다.
        return sortOrder == .oldestFirst ? Array(posts.reversed()) : posts
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

    // Figma `iPhone 17 - 13` 의 `Frame 28`(92:650): 362 폭 안에 170x186 카드가 두 장씩 세 줄.

    /// 카드 높이. 폭은 칸이 정한다 — 402 화면에서 170 이 되고 좁은 기기에서는 함께 줄어든다.
    ///
    /// 메모지 에셋(687x749)의 가로세로비가 170:186 과 거의 같다.
    /// 예전의 170 은 이보다 납작해서, 위아래가 잘리며 접힌 모서리도 함께 깎여 나갔다.
    private static let cardHeight: CGFloat = 186
    /// 카드 사이 가로 간격. 170 + 22 + 170 = 362 로 본문 폭에 딱 맞는다.
    private static let columnSpacing: CGFloat = 22
    /// 스크롤 막대를 본문 오른쪽 끝보다 얼마나 더 바깥으로 내보낼지.
    private static let indicatorOutset: CGFloat = 5
    /// 마지막 줄 아래 여백.
    ///
    /// 탭 바가 화면 아래에 떠 있고 그리드는 그 밑까지 뻗어 있다.
    /// 이 여백이 모자라면 **끝까지 밀어도 마지막 줄이 탭 바에 가린 채로 멈춘다.**
    /// 스크롤이 아예 안 되는 것처럼 보이는데, 사실은 더 내려갈 자리가 없는 것이다.
    ///
    /// 탭 바가 아래에서 차지하는 높이(≈66)에 손끝이 닿을 자리와 홈 인디케이터를 더해 잡았다.
    /// 마지막 줄 아래에 누를 수 있는 빈 자리를 남기는 몫도 겸한다.
    private static let bottomInset: CGFloat = 96
    /// 줄 사이 세로 간격. Figma 는 가로보다 좁은 17 을 쓴다 (186 세 줄 + 17 두 칸 = 592).
    private static let rowSpacing: CGFloat = 17

    private static let columns = [
        GridItem(.flexible(), spacing: columnSpacing),
        GridItem(.flexible(), spacing: columnSpacing)
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
                ScrollViewReader { grid in
                    LazyVGrid(columns: Self.columns, spacing: Self.rowSpacing) {
                        ForEach(currentPosts) { post in
                            card(for: post)
                        }
                    }
                    .padding(.bottom, Self.bottomInset)
                    // 넓힌 만큼 되돌려 카드는 제자리에 둔다. 아래 `indicatorOutset` 참고.
                    .padding(.trailing, Self.indicatorOutset)
                    .frame(maxWidth: .infinity, minHeight: 0, alignment: .top)
                    // 공유 화면이 덮고 있는 동안 미리 옮겨 둔다.
                    // 화면이 걷히면 그림이 이미 그 자리에 있어, 스크롤이 흐르는 것을 볼 일이 없다.
                    .onChange(of: postToShow) { _, target in
                        guard let target else { return }
                        grid.scrollTo(target, anchor: .center)
                        postToShow = nil
                    }
                }
            }
            // 스크롤 막대를 본문 밖으로 내보낸다.
            //
            // 막대는 `ScrollView` 의 오른쪽 끝에 선다.
            // 본문 여백(20) 안에 갇혀 있으면 카드와 너무 붙어 보인다.
            // 스크롤 영역만 밖으로 넓히고, 안의 카드는 같은 크기만큼 되돌려 제자리에 둔다.
            .padding(.trailing, -Self.indicatorOutset)
            // 카드보다 바깥쪽 제스처라, 카드 탭은 카드가 먼저 가져간다.
            .contentShape(Rectangle())
            .onTapGesture { onEmptyAreaTap?() }
        }
    }

    private func card(for post: Post) -> some View {
        let selected = isSelected(post)

        return paperLayer(.memoFront)
            .overlay {
                // 접힌 모서리 쪽으로 지는 그늘.
                //
                // 에셋은 평평한 종이라 그늘이 없다. 확대 카드와 같은 그라디언트를 덮어 준다.
                // 마스크가 본체만 덮으므로 접혀 올라온 삼각형은 에셋 색 그대로 남는다.
                // 삼각형은 종이 뒷면이라 앞면과 같은 방향으로 그늘이 질 이유가 없다.
                LinearGradient.doodlePaperFace
                    .mask { paperLayer(.memoFrontMask) }
            }
            // 접힌 삼각형을 그림자로 한 겹 들어 올린다.
            // 그늘이 지는 자리와 겹쳐 있어, 그냥 두면 접힌 자리인지 그늘인지 구분이 안 된다.
            .overlay { foldFlapShadow }
            .overlay {
                // 접힌 삼각형과 잘려나간 모서리에는 그림이 얹히지 않게 한다.
                // 마스크는 종이와 똑같은 배치를 거쳐야 접힌 자리가 정확히 맞는다.
                DoodleImageView(drawingData: post.drawingData)
                    .mask { paperLayer(.memoFrontMask) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            // 고른 카드는 어둡게 덮어서 한눈에 구분되게 한다.
            // 확인창은 세그먼트 아래에 떠서 이 카드를 가리지 않는다.
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

    /// 접혀 올라온 삼각형만 떼어내 그림자를 준 층.
    ///
    /// 삼각형은 종이 에셋에 그려져 있어 따로 그림자를 줄 수가 없다.
    /// 종이에서 본체를 지우면(`destinationOut`) 삼각형만 남으므로, 그것을 다시 얹는다.
    ///
    /// 그림자가 종이 밖으로 번지지 않게 종이 모양으로 잘라 둔다.
    /// 잘려나간 모서리는 뒤가 비치는 자리라, 거기까지 번지면 바탕에 얼룩이 진다.
    private var foldFlapShadow: some View {
        ZStack {
            paperLayer(.memoFront)
            paperLayer(.memoFrontMask)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
        .mask { paperLayer(.memoFront) }
    }

    /// 종이와 그 마스크가 같은 배치를 쓰도록 한곳에 모아 둔다.
    /// 셋(종이·그늘·그림)이 어긋나면 접힌 자리에 그림이나 그늘이 반쯤 걸친다.
    private func paperLayer(_ resource: ImageResource) -> some View {
        Image(resource)
            .resizable()
            .scaledToFill()
            .frame(height: Self.cardHeight)
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
            // 한 장만 고른다. 확인창은 GalleryPage 가 띄운다.
            // 카드를 꾹 눌러 「프로필 사진 설정」으로 들어온 길과 같은 곳으로 모인다.
            withAnimation(.spring()) { profileCandidatePost = post }
        }
    }
}

#Preview {
    PostGridView(
        mode: .browsing,
        segmentedBar: .constant(0),
        sortOrder: .newestFirst,
        selectedPost: .constant(nil),
        profileCandidatePost: .constant(nil),
        postPendingDelete: .constant(nil),
        postToShow: .constant(nil)
    )
    .modelContainer(LocalDataStore.makePreviewContainer())
}
