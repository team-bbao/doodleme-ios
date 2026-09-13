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
    /// 상세를 옆 칸에 펼쳐 두었는지. 그때만 열린 카드를 격자에서 짚어 준다.
    var showsDetailBeside = false
    @Binding var profileCandidatePost: Post?

    /// 지우려고 확인을 기다리는 그림. 확인창은 화면 가운데에 `GalleryPage` 가 띄운다.
    @Binding var postPendingDelete: Post?

    /// 지우려고 골라 둔 그림들. `selecting` 일 때만 채워진다.
    ///
    /// `Post` 자체가 아니라 식별자를 담는다.
    /// SwiftData 모델은 `Hashable` 이지만 지워지면 내용을 읽는 순간 터진다.
    /// 식별자만 들고 있으면 지워진 뒤에도 집합을 다루는 것 자체는 안전하다.
    @Binding var selectedPosts: Set<PersistentIdentifier>

    /// 카드를 꾹 눌러 고른 동작. 화면 전환은 `GalleryPage` 가 맡는다.
    var onShare: ((Post) -> Void)?

    /// 카드를 꾹 눌러 「선택」 을 고른 경우. 누른 카드가 첫 선택이 된다.
    var onStartSelecting: ((Post) -> Void)?

    /// 보여줘야 할 그림. 값이 들어오면 그 자리로 스크롤하고 도로 비운다.
    ///
    /// 방금 받은 그림이 화면 밖에 있을 수 있다.
    /// 최신순이면 맨 앞이라 그냥 보이지만, 오래된 순이면 맨 뒤에 붙는다.
    @Binding var postToShow: Post.ID?

    /// 그리기 화면이 방금 저장했다고 켜 둔 표시.
    @AppStorage(Post.showsJustSavedKey) private var showsJustSavedPost = false

    /// 격자가 실제로 받은 폭. 열 수와 카드 크기를 여기서 끌어낸다.
    /// 처음 한 번은 아이폰 본문 폭으로 두어, 재기 전에도 엉뚱한 배치가 스치지 않게 한다.
    @State private var gridWidth: CGFloat = 362

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
        case (.choosingProfile, true), (.selecting, true): "고를 수 있는 내 그림이 없어요"
        case (.choosingProfile, false), (.selecting, false): "고를 수 있는 받은 그림이 없어요"
        case (.browsing, true): "친구의 얼굴을 그려보세요"
        case (.browsing, false): "친구가 그린 그림을 받아보세요"
        }
    }

    // Figma `iPhone 17 - 13` 의 `Frame 28`(92:650): 362 폭 안에 170x186 카드가 두 장씩 세 줄.

    /// 아이폰(402 화면)에서의 카드 한 장 크기. 다른 화면에서는 이 비율을 지키며 늘고 준다.
    ///
    /// 메모지 에셋(687x749)의 가로세로비가 170:186 과 거의 같다.
    /// 예전의 170 은 이보다 납작해서, 위아래가 잘리며 접힌 모서리도 함께 깎여 나갔다.
    private static let baseCardWidth: CGFloat = 170
    private static let baseCardHeight: CGFloat = 186
    /// 카드 사이 가로 간격. 170 + 22 + 170 = 362 로 아이폰 본문 폭에 딱 맞는다.
    private static let baseColumnSpacing: CGFloat = 22

    /// 이 폭에서 카드 사이가 실제로 얼마나 벌어지는지.
    ///
    /// 고정 22 로 두면 iPad 에서 카드만 커져 상대적으로 더 붙어 보인다 —
    /// 아이폰은 22/170 = 12.9% 인데 13인치 가로에서는 22/204 = 10.8% 였다.
    /// 6열에서는 같은 간격이 다섯 번 반복되어 눈이 그 차이를 비교한다.
    static func columnSpacing(forWidth width: CGFloat) -> CGFloat {
        baseColumnSpacing * DoodleLayout.gridSpacingScale(forWidth: width)
    }

    /// 카드 한 장이 이보다 넓어지지 않는다.
    ///
    /// 예전에는 열 개수(셋)로 막았다. 그러면 13인치에서 세로도 가로도 똑같이 3열이 되어
    /// 방향 차이가 사라지고, 남는 폭이 전부 카드로 가 한 장이 431pt 까지 부풀었다.
    /// 폭으로 막으면 열 수가 방향에 따라 저절로 갈린다.
    ///
    /// 240 인 이유 — iPad 는 pt 당 물리 크기가 아이폰보다 16% 크지만 보는 거리가 1.4 배라,
    /// 아이폰에서와 같은 각크기로 보이려면 이만큼은 되어야 한다.
    /// 더 줄이면 이 앱의 가는 획이 뭉개져 무엇을 그린 것인지 알아보기 어려워진다.
    private static let maxCardWidth: CGFloat = 240

    /// 넓은 화면에서 글자를 얼마나 키울지. 아이폰에서는 1 이다.
    private static func scale(forWidth width: CGFloat) -> CGFloat {
        DoodleLayout.scale(forWidth: width)
    }

    /// 한 줄에 몇 장을 놓을지.
    ///
    /// 카드가 `maxCardWidth` 를 넘지 않는 **가장 적은** 열 수를 고른다.
    /// 열 수를 먼저 정하고 카드를 맞추는 것이 아니라, 카드 크기를 정하고 열 수가 따라온다.
    ///
    /// 아이폰(362)은 두 장이면 이미 170 이라 하한 2 에 걸려 지금과 같다.
    /// 13인치는 세로 992 에서 넷, 가로 1336 에서 여섯이 된다.
    private static func columnCount(forWidth width: CGFloat) -> Int {
        let spacing = columnSpacing(forWidth: width)
        let slot = maxCardWidth + spacing
        let needed = Int(((width + spacing) / slot).rounded(.up))
        return max(2, needed)
    }

    /// 주어진 폭에서 카드 한 장이 갖는 크기. 아이폰 402 화면에서는 170x186 그대로다.
    private static func cardSize(forWidth width: CGFloat) -> CGSize {
        let count = CGFloat(columnCount(forWidth: width))
        let w = (width - columnSpacing(forWidth: width) * (count - 1)) / count
        return CGSize(width: w, height: w * baseCardHeight / baseCardWidth)
    }
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
    ///
    /// 선택 바(높이 56 + 아래 여백 34 = 90)에 맞춘 값이다. 실측 틈 6.5pt.
    /// Dynamic Type 을 지원하게 되면 바 높이 + 안전영역으로 계산해야 한다.
    private static let bottomInset: CGFloat = 96
    /// 줄 사이 세로 간격. Figma 는 가로보다 좁은 17 을 쓴다 (186 세 줄 + 17 두 칸 = 592).
    /// 가로 간격과 같은 비율로 키운다 — 한쪽만 벌어지면 격자가 눌린 것처럼 보인다.
    private static let baseRowSpacing: CGFloat = 17

    private static func rowSpacing(forWidth width: CGFloat) -> CGFloat {
        baseRowSpacing * DoodleLayout.gridSpacingScale(forWidth: width)
    }

    /// 카드를 눌러 확대할 때의 결. `GalleryPage` 의 닫는 쪽과 같은 값을 쓴다.
    static let cardTransition: Animation = .spring(response: 0.32, dampingFraction: 0.86)

    /// 고른 카드를 덮는 농도.
    ///
    /// 프로필은 한 장만 고르므로 짙게 덮어도 헷갈릴 일이 없었다.
    /// 여러 장을 고를 때는 골라 둔 그림이 무엇인지도 계속 보여야 해서 그만큼 옅게 둔다.
    private static let selectedDimming: CGFloat = 0.28

    private static func columns(forWidth width: CGFloat) -> [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: columnSpacing(forWidth: width)),
            count: columnCount(forWidth: width)
        )
    }

    var body: some View {
        if currentPosts.isEmpty {
            // 위에 붙여 두면 카드가 놓일 자리가 아니라 헤더 바로 밑에서 뜬다.
            // 그리드가 차지할 영역 한가운데에 두어 "여기가 빈 자리" 임을 보여준다.
            Text(emptyMessage)
                .foregroundStyle(.colorGray)
                .fontWeight(.semibold)
                .font(.system(size: 20 * Self.scale(forWidth: gridWidth)))
                .opacity(0.4)
                .multilineTextAlignment(.center)
                // 글줄이 지나치게 길어지지 않게 묶는다.
                // 애플이 `readableContentGuide` 로 말하는 것과 같은 뜻 — 한 줄이 길면
                // 눈이 다음 줄 첫머리를 못 찾는다. 아이폰 폭보다 넓으므로 좁은 화면에서는 걸리지 않는다.
                .frame(maxWidth: DoodleLayout.readableWidth)
                // 아래 여백으로 글을 위로 밀어 올린다.
                // 그리드가 349 부터 화면 끝까지 차지하므로, 이 값이 클수록 글이 올라간다.
                // Figma 는 이 문구의 가운데를 522.5 에 둔다.
                .padding(.bottom, 178)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .onTapGesture { onEmptyAreaTap?() }
        } else {
            ScrollView {
                ScrollViewReader { grid in
                    LazyVGrid(columns: Self.columns(forWidth: gridWidth),
                              spacing: Self.rowSpacing(forWidth: gridWidth)) {
                        ForEach(currentPosts) { post in
                            card(for: post)
                        }
                    }
                    // 실제로 주어진 폭을 재서 열 수와 카드 크기를 정한다.
                    // 아이폰에서는 362 가 들어와 지금까지와 똑같이 두 장이 된다.
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { gridWidth = $0 }
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
            // 방금 저장하고 넘어온 경우에도 같은 길을 쓴다.
            // 표시가 먼저 켜질 수도, 그림이 먼저 들어올 수도 있어 양쪽을 다 본다.
            .onChange(of: showsJustSavedPost, initial: true) { _, _ in revealJustSaved() }
            .onChange(of: postsByMe.first?.id) { _, _ in revealJustSaved() }
            // 고르고 푸는 순간마다 손끝에 알린다.
            //
            // 카드가 옅게 덮이고 동그라미가 채워지는 것은 눈으로만 오는 신호다.
            // 여러 장을 빠르게 고를 때는 화면을 계속 확인하지 않게 되는데,
            // 그때 눌린 것이 먹었는지 알 길이 없다.
            .sensoryFeedback(.selection, trigger: selectedPosts)
        }
    }

    /// 방금 저장한 그림으로 옮겨 간다.
    ///
    /// 가장 최근에 만든 내 그림이 그것이다. 늘어놓는 순서와 상관없이
    /// `postsByMe` 는 최신순이라 맨 앞을 보면 된다.
    private func revealJustSaved() {
        guard showsJustSavedPost, let newest = postsByMe.first else { return }
        postToShow = newest.id
        showsJustSavedPost = false
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
            // 옆 칸에 열어 둔 카드를 격자에서 계속 짚어 준다.
            //
            // 애플 HIG 「Split views」 — *persistently highlight the current selection in each pane
            // that leads to the detail view. The selected appearance clarifies the relationship
            // between the content in various panes.*
            // 덮어서 보여 주던 때에는 상세가 격자를 가려 필요 없던 표시다.
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.doodlePrimary,
                                  lineWidth: isOpenInDetail(post) ? Self.openCardBorder : 0)
            }
            // 고른 카드는 어둡게 덮어서 한눈에 구분되게 한다.
            // 확인창은 세그먼트 아래에 떠서 이 카드를 가리지 않는다.
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(selected ? Self.selectedDimming : 0))
            }
            // 여러 장을 고를 때는 어둡게 덮는 것만으로 부족하다.
            //
            // 한 장만 고르는 프로필과 달리 고른 것과 안 고른 것이 화면에 섞여 있어,
            // 명암 차이만으로는 어느 쪽이 골라진 것인지 매번 다시 읽어야 한다.
            // 동그라미를 모든 카드에 띄워 "고를 수 있다" 를 먼저 알리고,
            // 채워진 동그라미로 "골랐다" 를 말한다.
            .overlay(alignment: .topTrailing) {
                if mode == .selecting {
                    selectionBadge(isOn: selected)
                        .padding(8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            .animation(.spring(response: 0.25, dampingFraction: 0.72), value: selected)
            .animation(.easeInOut(duration: 0.2), value: mode)
            .onTapGesture { handleTap(on: post) }
            .accessibilityAddTraits(selected ? [.isSelected] : [])
            .contextMenu { cardMenu(for: post) }
    }

    /// 고르는 중에 카드마다 붙는 동그라미.
    ///
    /// 시스템 심볼을 그대로 쓴다. 사진 앱에서 여러 장을 고를 때와 같은 모양이라
    /// 따로 배우지 않아도 무엇을 하는 자리인지 안다.
    private func selectionBadge(isOn: Bool) -> some View {
        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22, weight: isOn ? .semibold : .light))
            // 켜졌을 때만 색을 준다. 꺼진 동그라미까지 짙으면 그림 위에서 시끄럽다.
            .foregroundStyle(isOn ? Color.white : Color.white.opacity(0.9),
                             isOn ? Color.doodlePrimary : Color.clear)
            // 흰 종이 위에 흰 테두리라 그림자가 없으면 윤곽이 사라진다.
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
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

            // 여러 장을 지우러 가는 문.
            //
            // 삭제 바로 위에 둔다. 한 장만 지울 사람은 아래를 누르면 되고,
            // 누르다 보니 여러 장이더라 하는 사람은 같은 자리에서 갈아탈 수 있다.
            Button {
                onStartSelecting?(post)
            } label: {
                Label("선택", systemImage: "checkmark.circle")
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
            .frame(height: Self.cardSize(forWidth: gridWidth).height)
            .clipped()
    }

    /// 지금 옆 칸에 열려 있는 카드인지. 덮어서 보여 줄 때는 짚을 이유가 없다.
    private func isOpenInDetail(_ post: Post) -> Bool {
        showsDetailBeside && selectedPost?.persistentModelID == post.persistentModelID
    }

    private static let openCardBorder: CGFloat = 3

    private func isSelected(_ post: Post) -> Bool {
        switch mode {
        case .browsing:
            false
        case .choosingProfile:
            profileCandidatePost?.persistentModelID == post.persistentModelID
        case .selecting:
            selectedPosts.contains(post.persistentModelID)
        }
    }

    private func handleTap(on post: Post) {
        switch mode {
        case .browsing:
            // 여는 쪽에도 애니메이션을 건다.
            //
            // 닫을 때만 걸려 있어서 확대는 툭 튀어나오고 닫힘만 부드러웠다.
            // 같은 동작의 앞뒤가 다르게 움직이면 화면이 미끄러지다 걸리는 것처럼 느껴진다.
            withAnimation(Self.cardTransition) {
                selectedPost = post
            }

        case .choosingProfile:
            // 한 장만 고른다. 확인창은 GalleryPage 가 띄운다.
            // 카드를 꾹 눌러 「프로필 사진 설정」으로 들어온 길과 같은 곳으로 모인다.
            withAnimation(.spring()) { profileCandidatePost = post }

        case .selecting:
            // 같은 카드를 다시 누르면 선택이 풀린다.
            // 지우는 일이라 되돌릴 길을 눌렀던 그 자리에 둔다.
            let id = post.persistentModelID
            withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) {
                if selectedPosts.contains(id) {
                    selectedPosts.remove(id)
                } else {
                    selectedPosts.insert(id)
                }
            }
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
        selectedPosts: .constant([]),
        postToShow: .constant(nil)
    )
    .modelContainer(LocalDataStore.makePreviewContainer())
}
