//
//  ExportSinglePostCard.swift
//  DoodleMe
//

import SwiftUI

/// 그림 한 장을 내보내는 카드. Figma `iPhone 17 - 26`(`222:1655`).
///
/// 그림 한 장과 거기 딸린 한마디를 종이 위에 얹는다.
///
/// **받은 것과 내가 그린 것을 모두 낼 수 있다.** 제목의 두 이름이 서로 자리를 바꿀 뿐이다 —
/// 받은 것은 「**에리카**가 그린 / **케빈**의 첫인상」,
/// 내가 그린 것은 「**케빈**이 그린 / **미나**의 첫인상」.
struct ExportSinglePostCard: View {

    let post: Post
    /// 앱을 쓰는 나. 받은 것이면 그려진 사람, 내가 그린 것이면 그린 사람이다.
    let myName: String

    /// 그림을 그린 사람.
    private var drawer: String {
        post.isMine ? myName : post.displaySenderName
    }

    /// 그림에 그려진 사람.
    ///
    /// 내가 그린 것은 저장할 때 받는 사람 이름을 반드시 받으므로(`DrawingPage.canSave`)
    /// 비어 있을 일이 없다. 그래도 혹시 비면 이름 없이 「의 첫인상」 만 남지 않게 막아 둔다.
    private var subject: String {
        guard post.isMine else { return myName }
        return post.recipientName.isEmpty ? "너" : post.recipientName
    }

    var body: some View {
        ExportCard(
            title: ExportCardTitle(
                firstName: drawer,
                // 받침에 따라 「이」·「가」 가 갈린다. 하나로 못박으면 「케빈가 그린」 이 나온다.
                firstTail: "\(drawer.subjectParticle) 그린",
                secondName: subject,
                secondTail: "의 첫인상"
            )
        ) {
            memo
            quote
        }
    }

    // MARK: - 메모지

    /// 그림이 얹힌 종이. Figma `222:1759` 는 402 프레임에서 (28, 238) 346x379 — 9:16 으로 옮긴 값은 아래에 있다.
    ///
    /// 그림은 `DoodleImageView` 가 아니라 캐시가 구워 둔 `UIImage` 를 직접 쓴다.
    /// 그 뷰는 `.task` 로 그림을 늦게 채우는데 **화면에 붙지 않은 뷰에서는 그 task 가 돌지 않아**,
    /// 그대로 구우면 획 없는 빈 종이가 나온다 — `PostDetailView.snapshotData()` 에 같은 기록이 있다.
    private var memo: some View {
        ZStack(alignment: .topLeading) {
            // 갤러리가 쓰는 `memo` 가 아니라 따로 받은 에셋이다.
            //
            // 크기는 686x749 로 같지만 그림이 다르다 —
            // `memo` 는 왼쪽 끝이 243 으로 어둡게 깔린 그러데이션이고, 이쪽은 250 으로 고르다.
            // 종이 질감 위에 얹으면 그 그늘이 얼룩처럼 비쳐 Figma 와 어긋난다.
            Image(.exportMemo)
                .resizable()
                .frame(width: Self.memoSize.width, height: Self.memoSize.height)
                .shadow(color: .black.opacity(0.15), radius: 15, y: 4)

            // 그림은 **종이 전체**를 덮는다.
            //
            // `canvasImage()` 가 350x390 캔버스를 통째로 굽고, 그 안에 획이 이미 제자리를 잡고 있다.
            // 그리드·상세도 같은 이미지를 종이 위에 그대로 덮어 쓴다.
            // Figma 의 `Vector 7`(221x218)은 디자이너가 그려 넣은 **예시 그림**이라
            // 그 좌표에 맞춰 밀어 넣으면 실제 그림이 종이 안에서 왼쪽 위로 치우친다.
            //
            // 접힌 모서리 위에 획이 얹히지 않도록 그리드와 같은 마스크를 쓴다.
            Image(uiImage: DoodleImageCache.image(for: post.drawingData))
                .resizable()
                .frame(width: Self.memoSize.width, height: Self.memoSize.height)
                .mask {
                    Image(.memoFrontMask)
                        .resizable()
                        .frame(width: Self.memoSize.width, height: Self.memoSize.height)
                }

            // 앱 마크. 종이 왼쪽 위에 도장처럼 찍힌다. Figma `222:1812`.
            Image(.doodleMark)
                .resizable()
                .frame(width: Self.markSide, height: Self.markSide)
                .offset(x: Self.markOrigin.x - Self.memoOrigin.x,
                        y: Self.markOrigin.y - Self.memoOrigin.y)
        }
        .offset(x: Self.memoOrigin.x, y: Self.memoOrigin.y)
    }

    // MARK: - 한마디

    /// 그림에 딸려 온 한마디. 양옆에 따옴표가 붙는다. Figma `222:1769`.
    ///
    /// 따옴표는 `Crimson Text` Bold 80 이다. 손글씨체에는 쓸 만한 따옴표 글리프가 없어 따로 들였다.
    /// 닫는 따옴표는 여는 것을 180도 돌린 것이다 — Figma 도 같은 글자를 뒤집어 쓴다.
    @ViewBuilder
    private var quote: some View {
        // 한마디가 없으면 따옴표도 그리지 않는다.
        // 빈 자리에 여는 따옴표와 닫는 따옴표만 남으면 무언가 지워진 것처럼 보인다.
        if !post.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            quoteBody
        }
    }

    private var quoteBody: some View {
        let top = quoteTop
        let lastLine = top + CGFloat(quoteLines - 1) * Self.quoteLineHeight

        return ZStack(alignment: .topLeading) {
            // 폭을 넘기면 줄을 나눈다.
            // 폭을 주지 않으면 한 줄에 우겨넣다가 「...」로 잘린다.
            BakedLineHeightText(
                post.text,
                font: .doodleHandwriting(size: Self.quoteTextFontSize),
                lineHeight: Self.quoteLineHeight,
                color: .doodlePrimary,
                width: Self.quoteTextSize.width,
                maxLines: Self.maxQuoteLines
            )
            .frame(width: Self.quoteTextSize.width)
            .offset(x: Self.quoteTextOrigin.x, y: top)

            // 따옴표는 글과 함께 움직인다. 여는 쪽은 첫 줄, 닫는 쪽은 **마지막 줄**에 선다 —
            // Figma 도 두 줄짜리 예시에서 닫는 따옴표 칸을 둘째 줄에 두었다(644 + 44 = 688).
            // 획은 그 한 줄 위에 그려진다 — `closeQuoteLeft` 에 기록이 있다.
            mark(at: CGPoint(x: Self.openQuoteOrigin.x, y: top), flipped: false)
            mark(at: CGPoint(x: closeQuoteLeft, y: lastLine), flipped: true)
        }
    }

    /// 닫는 따옴표의 왼쪽.
    ///
    /// **글이 끝나는 자리를 따라간다.** Figma 처럼 한 자리에 못박지 않는다.
    ///
    /// Figma 는 402 프레임에서 글상자(89~359)와 닫는 따옴표(312~354)를 **47 겹쳐** 두었다.
    /// 예시 글의 마지막 줄 「꼭 징징이 같아요」가 가운데 정렬로 309 에서 끝나
    /// 따옴표를 3 차이로 비켜갈 뿐이라, 한마디가 조금만 길면 글자 위에 그대로 얹힌다 —
    /// 구운 파일에서 「초승달처」를 덮었다.
    ///
    /// **마지막 줄뿐 아니라 그 윗줄도 피해야 한다.** 따옴표는 80pt 글리프를 34 높이 칸에 담은 것이라
    /// 칸을 마지막 줄에 두어도 **잉크는 한 줄 위 높이에 그려진다** — Figma 의 두 줄짜리 예시도
    /// 칸은 둘째 줄(688)인데 획은 첫 줄 자리에 있다. 마지막 줄만 보고 자리를 잡았더니
    /// 짧은 마지막 줄 뒤에 섰다가 긴 윗줄의 「접히」를 덮었다.
    ///
    /// 그래서 획이 걸치는 **두 줄 중 더 긴 쪽** 끝에 붙인다.
    /// 짧으면 Figma 와 거의 같은 자리에 서고, 길면 그만큼 오른쪽으로 물러난다.
    /// 오른쪽 끝(카드 안쪽 여백)을 넘지는 않는다.
    private var closeQuoteLeft: CGFloat {
        let font = UIFont.doodleHandwriting(size: Self.quoteTextFontSize)
        let lines = BakedLineHeightText.wrapped(post.text,
                                                font: font,
                                                width: Self.quoteTextSize.width)
        // 글이 가운데 정렬이라 각 줄은 글상자 한가운데에 놓인다.
        let right = { (line: String) -> CGFloat in
            let width = (line as NSString).size(withAttributes: [.font: font]).width
            return Self.quoteTextOrigin.x + (Self.quoteTextSize.width + width) / 2
        }
        let spanned = lines.suffix(2).map(right).max() ?? Self.quoteTextOrigin.x
        // 오른쪽 끝은 카드 안에 머문다.
        let limit = ExportCardLayout.contentWidth - Self.quoteSize.width - ExportCardLayout.sideMargin
        return min(spanned + Self.closeQuoteGap, limit)
    }

    /// 마지막 글자와 닫는 따옴표 사이. Figma 예시에서 재면 3 이지만 그건 아슬아슬한 값이라
    /// 눈에 띄게 띄운다.
    private static let closeQuoteGap: CGFloat = 8

    /// 한마디 글꼴 크기. 줄을 나누고 폭을 잴 때 같은 값을 써야 한다.
    private static let quoteTextFontSize: CGFloat = 30

    /// 한마디가 차지하는 줄 수. 넘치면 `maxQuoteLines` 에서 끊긴다.
    private var quoteLines: Int {
        let counted = BakedLineHeightText.lineCount(
            post.text,
            font: .doodleHandwriting(size: Self.quoteTextFontSize),
            width: Self.quoteTextSize.width
        )
        return min(max(counted, 1), Self.maxQuoteLines)
    }

    /// 한마디 첫 줄의 윗변.
    ///
    /// 두 줄까지는 제자리(688)에 선다. 그보다 길어지면 **위로 밀어 올린다** —
    /// 그러지 않으면 꼬리말(812) 자리로 흘러내린다. 긴 한마디를 구워 보니
    /// 마지막 줄이 「너도 친구의 첫인상을 그려봐.」 에 닿았다.
    private var quoteTop: CGFloat {
        let height = CGFloat(quoteLines) * Self.quoteLineHeight
        return min(Self.quoteTextOrigin.y, Self.quoteBandBottom - height)
    }

    /// 따옴표 한 개.
    ///
    /// 닫는 쪽은 **좌우로 뒤집는다.**
    /// Figma 는 `-scale-y-100` 과 `rotate-180` 을 함께 걸어 두었는데,
    /// 위아래 반전과 180도 회전을 합치면 결국 좌우 반전이다.
    /// 180도 회전만 걸면 글자가 거꾸로 서고 자리도 어긋난다 — 처음에 그렇게 해서 24 오른쪽,
    /// 36 아래로 밀렸다.
    private func mark(at origin: CGPoint, flipped: Bool) -> some View {
        Text("\u{201C}")
            .font(.custom(Self.quoteFontName, size: Self.quoteFontSize))
            .foregroundStyle(Self.quoteColor)
            .frame(width: Self.quoteSize.width, height: Self.quoteSize.height)
            .scaleEffect(x: flipped ? -1 : 1, y: 1)
            .offset(x: origin.x, y: origin.y)
    }

    // MARK: - 자리

    /// 메모지. **본문 자리의 폭을 다 쓰고, 높이는 Figma 비율(346:379)이 정한다.**
    ///
    /// Figma 는 402 프레임에서 (28, 238) 346x379 였다. 9:16 카드에서는 좌우 여백만 그 28 을
    /// 물려받고 폭은 434 로 늘어난다 — 카드 폭의 88.6%.
    ///
    /// 그림이 `.resizable()` 로 **종이 전체**를 덮으므로 비율을 어기면 그림이 늘어난다.
    /// 그래서 높이는 고르는 값이 아니라 폭에서 따라 나온다.
    private static let memoSize = CGSize(
        width: ExportCardLayout.contentWidth - ExportCardLayout.sideMargin * 2,
        height: (ExportCardLayout.contentWidth - ExportCardLayout.sideMargin * 2) * 379 / 346
    )
    private static let memoOrigin = CGPoint(x: ExportCardLayout.sideMargin,
                                            y: ExportCardLayout.bodyTop)

    /// 앱 마크. Figma 가 종이 안에 둔 자리(9, 10)와 크기(67)를 종이와 같은 배율로 키운다.
    private static let markScale = memoSize.width / 346
    private static let markOrigin = CGPoint(x: memoOrigin.x + 9 * markScale,
                                            y: memoOrigin.y + 10 * markScale)
    private static let markSide: CGFloat = 67 * markScale

    /// 한마디 글상자. **따옴표까지가 좌우 여백 28 에 맞아떨어지게 잡는다.**
    ///
    /// 여는 따옴표가 28 에서 시작하고, 7 띄우고 글상자가 온다.
    /// 닫는 따옴표도 오른쪽에서 28 을 남기므로 글상자는 양쪽에서 77 씩 들어간 336 이다.
    /// 메모지·격자·말풍선이 모두 같은 28 을 쓰니 카드 전체의 좌우 선이 하나로 맞는다.
    ///
    /// 세로는 **아래에서 잰다.** 글 아랫변이 본문 자리의 아랫변(755.6)에 닿아
    /// 꼬리말과의 간격이 리듬(36) 그대로 떨어진다.
    private static let quoteGapToBox: CGFloat = 7
    private static let quoteTextSize = CGSize(
        width: ExportCardLayout.contentWidth
            - (ExportCardLayout.sideMargin + quoteSize.width + quoteGapToBox) * 2,
        height: quoteLineHeight * CGFloat(maxQuoteLines)
    )
    private static let quoteTextOrigin = CGPoint(
        x: ExportCardLayout.sideMargin + quoteSize.width + quoteGapToBox,
        y: ExportCardLayout.bodyBottom - quoteTextSize.height
    )
    private static let openQuoteOrigin = CGPoint(x: ExportCardLayout.sideMargin,
                                                 y: quoteTextOrigin.y)
    private static let quoteSize = CGSize(width: 42, height: 34)

    private static let quoteLineHeight: CGFloat = 44

    /// 담을 수 있는 최대 줄 수.
    ///
    /// **둘이면 넉넉하다.** 한마디는 30자까지고(`DrawingPage.textLimit`),
    /// 336 짜리 글상자 두 줄이면 672 를 담는다 — 가장 넓은 한글 30자가 570 언저리라
    /// 줄바꿈이 한 낱말을 통째로 넘겨도 들어간다.
    /// 셋으로 늘리면 그만큼 메모지가 작아지는데, 쓰이지 않을 셋째 줄이다.
    private static let maxQuoteLines = 2

    /// 한마디 띠의 위·아랫변. 글상자가 곧 띠다.
    private static let quoteBandTop = quoteTextOrigin.y
    private static let quoteBandBottom = ExportCardLayout.bodyBottom

    /// PostScript 이름. 파일은 `Resources/Fonts/CrimsonText-Bold.ttf`, `Info.plist` 의 `UIAppFonts` 에 등록돼 있다.
    private static let quoteFontName = "CrimsonText-Bold"
    private static let quoteFontSize: CGFloat = 80
    /// Figma `#7a7a7a`.
    private static let quoteColor = Color(red: 0x7A / 255, green: 0x7A / 255, blue: 0x7A / 255)
}
