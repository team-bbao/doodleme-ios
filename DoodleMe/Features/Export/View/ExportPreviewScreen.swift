//
//  ExportPreviewScreen.swift
//  DoodleMe
//

import SwiftUI

/// 내보낼 카드 한 장.
///
/// 고른 그림이 한 장에 다 안 들어가면 여러 장이 된다.
/// 인스타그램 캐러셀이 한 게시물에 20장까지 받으므로, 나눈 페이지를 그대로 올릴 수 있다.
struct ExportPage: Identifiable {
    let id: Int
    let card: AnyView

    init(id: Int, @ViewBuilder card: () -> some View) {
        self.id = id
        self.card = AnyView(card())
    }
}

/// 내보낼 카드를 먼저 보여 주는 화면.
///
/// Figma `iPhone 17 - 26 / 27 / 28` 이 402x871 아이폰 화면 모양이고 상태바까지 얹혀 있다 —
/// 그림 파일 규격이 아니라 **앱 안에서 보는 화면**이라는 뜻이다.
///
/// 무엇을 내보내는지 보고 누르게 한다. 한 번 나가면 되돌릴 수 없는 일이라
/// 미리 보여 주는 편이 낫다.
struct ExportPreviewScreen: View {

    let pages: [ExportPage]
    /// 임시 파일 이름의 앞자리. 공유 시트에서 파일명으로도 보인다.
    let fileName: String
    let onClose: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var files: [URL] = []
    @State private var current = 0
    /// 어느 자리에 올릴 판인지. 스토리로 시작한다 — 원래 이 화면이 만들어진 규격이다.
    @State private var ratio: ExportRatio = .story

    /// 고른 판형의 카드 크기.
    private var layout: ExportCardLayout { ExportCardLayout(ratio: ratio) }

    var body: some View {
        GeometryReader { proxy in
            TabView(selection: $current) {
                ForEach(Array(slides(in: proxy.size).enumerated()), id: \.offset) { index, slide in
                    slideView(slide, in: proxy)
                        .tag(index)
                }
            }
            // 페이지 점은 시스템 것을 그대로 쓴다. 아무것도 지정하지 않는다.
            //
            // `.page` 의 기본은 `IndexDisplayMode.automatic` —
            // *Displays an index view when there are more than one page.*
            // 한 장이면 알아서 안 내고 여러 장이면 낸다. 우리가 장수를 세어 `.always` 를
            // 걸어 둘 이유가 없다. 그건 「한 장일 때도 늘 켠다」 는 뜻이다.
            //
            // 배경(알약)도 지정하지 않는다. 기본이 HIG 「Page controls」 의 **Automatic** —
            // *Displays the background only when people interact with the control.*
            // `always` 로 두면 알약이 꼬리말 「@doodle.me」 를 통째로 덮는다.
            //
            // 점 색도 칠하지 않는다. HIG: *Avoid coloring indicator images… let the system
            // automatically color the indicators.*
            .tabViewStyle(.page)
            // 카드들이 저마다 폭을 알아야 한다. 한 군데서 내리면 안쪽이 전부 따라온다.
            .environment(\.exportRatio, ratio)
            // 버튼을 **카드 폭에 맞춰** 얹는다. 안전영역은 여기서만 지킨다.
            //
            // 바깥에 두면 화면 폭을 차지해, 카드가 9:16 이라 좌우가 남는
            // 아이패드 가로에서 버튼만 검은 여백 맨 끝에 붙는다.
            // 카드와 관계없는 것처럼 보이고 1180 폭에서는 손도 닿지 않는다.
            .overlay(alignment: .top) {
                topBar
                    .frame(maxWidth: slideWidth(columns: cardsOnCurrentSlide(in: proxy.size))
                           * fit(in: proxy.size))
                    .padding(.top, topInset(in: proxy))
            }
        }
        // `.ignoresSafeArea()` 는 `GeometryReader` **자신**에게 걸어야 한다.
        //
        // 안쪽에 걸면 그리는 자리만 넓어지고 `proxy.size` 는 그대로 안전영역 안쪽(402x781)을
        // 돌려준다. 그러면 배율이 0.897 로 떨어져 카드가 화면 한가운데 작게 뜬다.
        // `PaperBackground` 주석에 적힌 것과 같은 함정이다.
        .ignoresSafeArea()
        // 판을 바꾸면 다시 굽는다. 공유 시트에는 지금 보고 있는 판만 나가야 한다.
        .task(id: ratio) { bake() }
    }

    /// 카드 한 장을 화면에 꽉 채워 놓는다.
    ///
    /// **`TabView` 가 내용을 제자리에 놓아 주지 않는다.**
    /// `GeometryReader` 는 화면 맨 위(y=0)에 서 있는데 그 안의 페이지는 y=14 에서 시작한다.
    /// 점을 내든 안 내든(`indexDisplayMode`) 똑같이 14 만큼 밀린다 — 재서 확인했다.
    /// 그대로 두면 종이 위쪽에 흰 띠가 14 남고 아래는 그만큼 잘린다.
    ///
    /// 그래서 페이지가 놓인 자리를 직접 재서 되돌린다.
    /// `14` 를 적어 두지 않는 것은 기기마다 다를 수 있어서다 — 두 자리의 차이를 그때그때 잰다.
    /// 한 장(좁은 화면) 또는 두 장(눕힌 아이패드)을 담은 슬라이드 하나.
    ///
    /// **`TabView` 가 내용을 제자리에 놓아 주지 않는다.**
    /// `GeometryReader` 는 화면 맨 위(y=0)에 서 있는데 그 안의 페이지는 y=14 에서 시작한다.
    /// 점을 내든 안 내든(`indexDisplayMode`) 똑같이 14 만큼 밀린다 — 재서 확인했다.
    /// 그대로 두면 종이 위쪽에 흰 띠가 14 남고 아래는 그만큼 잘린다.
    ///
    /// 그래서 페이지가 놓인 자리를 직접 재서 되돌린다.
    /// `14` 를 적어 두지 않는 것은 기기마다 다를 수 있어서다 — 두 자리의 차이를 그때그때 잰다.
    private func slideView(_ slide: [ExportPage], in proxy: GeometryProxy) -> some View {
        GeometryReader { inner in
            ZStack {
                Self.backdrop

                // 둥근 모서리와 그림자는 **화면에서만** 붙는다.
                // 굽는 쪽(`bake`)은 카드를 따로 그리므로 내보내는 파일에는 들어가지 않는다.
                //
                // 카드가 9:16 이라 위아래(또는 좌우)에 배경이 남는데, 종이와 배경 색이 거의 같아
                // 종이가 화면 끝에서 **잘린 것처럼** 보였다.
                // 사진 앱이 사진 한 장을 보여줄 때와 같은 모양으로 두면 한 장이라는 게 바로 읽힌다.
                HStack(spacing: Self.slideGap) {
                    ForEach(slide) { page in
                        page.card
                            .clipShape(RoundedRectangle(cornerRadius: Self.previewCornerRadius,
                                                        style: .continuous))
                            .shadow(color: .black.opacity(0.45), radius: 20, y: 8)
                    }
                }
                .scaleEffect(fit(in: proxy.size))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .offset(y: proxy.frame(in: .global).minY - inner.frame(in: .global).minY)
        }
    }

    /// 한 번에 보여 줄 장수.
    ///
    /// 눕힌 아이패드는 좌우가 크게 남는다 — 9:16 카드 하나를 가운데 놓으면
    /// 양옆 검은 띠가 화면의 40% 를 먹는다. 두 장을 나란히 놓으면 그 자리가 살고
    /// 넘길 횟수도 반으로 준다.
    ///
    /// 세로는 좌우가 남지 않고, 아이폰은 어느 방향이든 좁다.
    private func columns(in size: CGSize) -> Int {
        DoodleLayout.isWide(size.width, sizeClass: horizontalSizeClass)
            && size.width > size.height ? 2 : 1
    }

    /// 넘길 단위. 한 슬라이드에 `columns` 장이 들어간다.
    private func slides(in size: CGSize) -> [[ExportPage]] {
        pages.chunked(by: columns(in: size))
    }

    /// 지금 보고 있는 슬라이드에 **실제로** 놓인 장수.
    ///
    /// 마지막 슬라이드는 `columns` 보다 적을 수 있다 — 5쪽을 두 장씩 넘기면 마지막은 한 장이다.
    /// 버튼 줄을 늘 `columns` 기준으로 재면, 그 한 장짜리 슬라이드에서 닫기·공유가
    /// 카드에서 멀찍이 떨어진 검은 여백 끝에 붙는다. 눕힌 아이패드에서 실제로 그랬다.
    private func cardsOnCurrentSlide(in size: CGSize) -> Int {
        let all = slides(in: size)
        guard all.indices.contains(current) else { return columns(in: size) }
        return all[current].count
    }

    /// 슬라이드 하나가 원래 좌표계에서 차지하는 폭.
    private func slideWidth(columns: Int) -> CGFloat {
        layout.size.width * CGFloat(columns) + Self.slideGap * CGFloat(columns - 1)
    }

    /// 나란히 놓인 카드 사이.
    private static let slideGap: CGFloat = 24

    /// 버튼 줄이 화면 위에서 떨어져 있는 정도.
    ///
    /// **카드 위에 자리가 있으면 카드 밖에 선다.**
    /// 판이 넓어질수록 카드는 낮아져 위아래 빈 바탕이 넓어진다 —
    /// 1:1 은 아이폰에서 위로 236 이 남는다. 그 자리를 두고 카드 안으로 들어가면
    /// 세그먼트가 제목(「○○가 그린」)을 덮는다. 실제로 덮였다.
    ///
    /// 자리가 모자라면 예전대로 카드 윗변 안쪽으로 들어간다.
    /// 9:16 을 아이폰에 띄우면 카드가 화면을 거의 채워 위에 20 밖에 안 남는데,
    /// 거기서는 제목 위 여백(106)이 넉넉해 겹치지 않는다.
    ///
    /// 어느 쪽이든 안전영역 아래로 `topGap` 만큼은 내려온다.
    /// 가로에서는 안전영역이 24 밖에 안 돼 그대로 두면 버튼이 화면 맨 위에 붙는다.
    private func topInset(in proxy: GeometryProxy) -> CGFloat {
        let cardTop = (proxy.size.height - layout.size.height * fit(in: proxy.size)) / 2
        let safeTop = proxy.safeAreaInsets.top

        let aboveCard = cardTop - Self.topGap - Self.barHeight
        if aboveCard >= safeTop + Self.topGap { return aboveCard }

        return max(safeTop, cardTop) + Self.topGap
    }

    /// 카드를 화면에 들어가게 맞추는 배율. 잘리지 않게 짧은 쪽에 맞춘다.
    ///
    /// 카드는 9:16 인데 아이폰 화면은 그보다 길쭉해(402x874 = 9:19.6) 폭에 맞춘다.
    /// 그러면 위아래에 각 80 쯤 빈자리가 남는다 — **이건 잘못이 아니라 그대로가 맞다.**
    /// 꽉 채우려고 키우면 화면에 보이는 것과 실제로 나가는 그림이 달라진다.
    /// 남는 자리는 닫기·공유 버튼이 앉아 종이를 가리지 않게 된다.
    private func fit(in size: CGSize) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return 1 }

        // 여러 장이면 아래쪽에 페이지 점이 설 자리를 비운다.
        //
        // 비우지 않으면 카드가 화면 높이를 꽉 채우는 곳에서 점이 **종이 위에** 얹힌다 —
        // 아이패드 세로의 9:16 이 정확히 그랬고, 점이 「@doodle.me」 바로 아래에 찍혀
        // 내보낸 그림에 들어가는 것처럼 보였다.
        // 위아래를 같이 비워야 카드가 계속 한가운데에 선다.
        let room = pages.count > 1 ? Self.indexRoom * 2 : 0
        return min(size.width / slideWidth(columns: columns(in: size)),
                   max(size.height - room, 1) / layout.size.height)
    }

    private func bake() {
        // 판형을 파일 이름에 남긴다. 사진 앱에 여러 판을 저장해 두었을 때
        // 어느 것이 스토리용이고 어느 것이 게시물용인지 열어 보지 않고 가린다.
        files = pages.compactMap {
            ExportRenderer.temporaryFile($0.card,
                                         ratio: ratio,
                                         name: "\(fileName)-\(ratio.fileTag)-\($0.id + 1)")
        }
    }

    /// 카드 위에 떠 있는 줄. 양 끝에 버튼, 가운데에 판형 세그먼트.
    private var topBar: some View {
        HStack {
            Button(action: onClose) { buttonFace("xmark") }
                .buttonStyle(.glass)
                .accessibilityLabel("닫기")

            Spacer()

            // 애플 HIG 「Activity views」 — 공유 버튼으로 시스템 시트를 연다.
            // 사진 저장·인스타그램·AirDrop 이 전부 이 안에 들어 있어 버튼을 따로 두지 않는다.
            //
            // 여러 장이면 전부 넘긴다. 사진 앱에 다 저장해 두면
            // 인스타그램에서 골라 캐러셀 한 게시물로 올릴 수 있다.
            if !files.isEmpty {
                ShareLink(items: files) { buttonFace("square.and.arrow.up") }
                    .buttonStyle(.glass)
                    .accessibilityLabel(files.count > 1 ? "\(files.count)장 공유" : "공유")
            }
        }
        .padding(.horizontal, Self.sideInset)
        // `.glass` 가 기본으로 주는 모양은 캡슐이라 44 짜리 글리프에 좌우 여백이 붙어
        // 알약처럼 늘어난다. 갤러리 상단 버튼들과 같은 원으로 맞춘다.
        .buttonBorderShape(.circle)
        // 세그먼트를 **겹쳐서** 가운데에 둔다.
        //
        // 같은 `HStack` 에 넣으면 공유 버튼이 아직 안 나왔을 때(굽는 중) 한쪽으로 쏠린다.
        // 겹쳐 두면 버튼이 있든 없든 늘 화면 한가운데 선다.
        .overlay { ratioPicker }
    }

    /// 어느 자리에 올릴지 고르는 세그먼트.
    ///
    /// 애플 기본 `.segmented` 그대로다. HIG 「Segmented controls」 —
    /// *Use a segmented control to offer closely related choices that affect an object,
    /// state, or view* — 같은 그림을 어느 판으로 내보낼지가 꼭 그 자리다.
    ///
    /// 고르면 미리보기가 바로 그 판으로 바뀐다. 나가기 전에 무엇이 나갈지 보게 하는 것이
    /// 이 화면의 일이라, 굽는 순간에 묻는 메뉴보다 여기가 맞다.
    private var ratioPicker: some View {
        Picker("판형", selection: $ratio) {
            ForEach(ExportRatio.allCases) { ratio in
                Text(ratio.label)
                    .accessibilityLabel(ratio.accessibilityLabel)
                    .tag(ratio)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        // 좌우 버튼(각 44)과 부딪히지 않는 폭이다. 가장 좁은 아이폰에서도 60 씩 남는다.
        .frame(maxWidth: Self.ratioPickerWidth)
    }

    /// 버튼 알맹이. 바탕은 `.glass` 버튼 스타일이 깔아 준다.
    ///
    /// 흰 원을 직접 그리지 않는다.
    /// 애플 HIG 「Materials」 — *Liquid Glass forms a distinct functional layer for controls
    /// and navigation elements … that floats above the content layer* —
    /// 카드 위에 떠 있는 이 두 개가 바로 그 자리다.
    ///
    /// 갤러리 상단 버튼은 Figma 가 흰 원·먹색 원으로 정해 둔 것이라 그대로 두고,
    /// 여기만 유리로 간다. HIG 도 *Use Liquid Glass effects sparingly … Limit these effects
    /// to the most important functional elements* 라고 못박는다.
    ///
    /// 재질을 우리가 고르지 않는다. 시스템이 뒤에 무엇이 있는지 보고 정한다 —
    /// 어두운 바탕 위에서도, 종이 위로 걸쳐도 알아서 읽히게 맞춘다.
    private func buttonFace(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.title3.weight(.semibold))
            .frame(width: 44, height: 44)
    }

    private static var sideInset: CGFloat { 18 }
    /// 판형 세그먼트의 최대 폭.
    private static let ratioPickerWidth: CGFloat = 220
    /// 버튼 줄의 높이. 글리프 하나가 44 니 줄도 44 다.
    private static let barHeight: CGFloat = 44
    /// 카드 아래에 비워 두는 페이지 점 자리.
    private static let indexRoom: CGFloat = 44
    /// 버튼이 안전영역·카드 윗변에서 떨어지는 정도. 좌우 여백과 같은 값이다.
    private static let topGap: CGFloat = 18

    /// 카드 뒤에 까는 바탕.
    ///
    /// **앱에서 유일하게 어두운 화면이다.** 그럴 이유가 있다.
    /// 카드는 9:16 이라 19.5:9 인 화면에서 위아래가 남는데, 종이(241,241,246)와
    /// 원래 배경(242,242,247)이 **1 차이**라 경계가 보이지 않았다.
    /// 종이가 화면 끝에서 잘린 것처럼 읽혀 「내보내면 잘리나?」 하는 오해를 낳았다.
    /// 둥근 모서리와 그림자만으로는 모자랐다 — 흰 것 뒤에는 어두운 것이 있어야 한다.
    ///
    /// 셋로그가 만든 영상을 검은 판 위에 얹어 보여 주는 것과 같은 까닭이다.
    /// 이 화면은 감상하는 자리가 아니라 **무엇이 나가는지 확인하는 자리**다.
    private static let backdrop = Color(white: 0.13)

    /// 미리보기에서만 깎는 모서리. 카드 좌표(490 폭) 기준이라 화면에서는 20 쯤으로 보인다.
    private static let previewCornerRadius: CGFloat = 24
}
