//
//  ExportSinglePostCard.swift
//  DoodleMe
//

import SwiftUI

/// 그림 한 장을 내보내는 카드. Figma 최종시안 `424:792`(`424:863` 이 캔버스 자리를 표시한 판).
///
/// 그림 한 장과 거기 딸린 한마디를 종이 위에 얹는다.
///
/// **메모지를 깔지 않는다.** 예전 도안(`iPhone 17 - 26`)은 흰 메모지 위에 그림을 얹고
/// 왼쪽 위에 앱 마크를 찍었는데, 최종시안은 그 둘을 다 걷어 내고 **구겨진 종이에 바로** 그린다.
/// 카드 전체가 한 장의 종이라는 인상이 살고, 종이 안에 또 종이가 있던 겹이 사라진다.
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
            ),
            titleTop: ExportCardLayout.singleTitleTop
        ) {
            drawing
            quote
        }
    }

    // MARK: - 그림

    /// 종이에 바로 얹히는 그림. Figma `424:882`(`Rectangle 8`)가 **캔버스 자리**로 표시해 둔 288x314.
    ///
    /// 디자이너가 그 자리를 투명한 상자로 그려 두었다 — 「여기에 캔버스가 들어간다」 는 뜻이다.
    /// 그 안에 그려 둔 예시 그림(`Vector 1`, 188x201)의 자리에 맞추지 않는다.
    /// 그건 디자이너가 손으로 그린 한 장일 뿐이라, 그 좌표에 밀어 넣으면
    /// 실제 그림이 상자 안에서 왼쪽 위로 치우친다.
    ///
    /// 그림은 `DoodleImageView` 가 아니라 캐시가 구워 둔 `UIImage` 를 직접 쓴다.
    /// 그 뷰는 `.task` 로 그림을 늦게 채우는데 **화면에 붙지 않은 뷰에서는 그 task 가 돌지 않아**,
    /// 그대로 구우면 획 없는 빈 종이가 나온다 — `PostDetailView.snapshotData()` 에 같은 기록이 있다.
    private var drawing: some View {
        Image(uiImage: DoodleImageCache.image(for: post.drawingData))
            .resizable()
            .frame(width: Self.drawingSize.width, height: Self.drawingSize.height)
            .offset(x: Self.drawingOrigin.x, y: Self.drawingOrigin.y)
    }

    // MARK: - 한마디

    /// 그림에 딸려 온 한마디. 양옆에 따옴표가 붙는다. Figma `424:883`·`424:884`·`424:885`.
    ///
    /// 따옴표는 **글꼴이 아니라 그림**이다. 최종시안이 21x18 짜리 벡터 한 쌍으로 바꿨다 —
    /// 예전에는 `Crimson Text` Bold 80 을 34 짜리 칸에 담아 썼는데, 그러면 획이 칸 밖
    /// 한 줄 위까지 삐져나와 글자를 덮었다. 닫는 쪽은 여는 것을 좌우로 뒤집어 쓴다.
    @ViewBuilder
    private var quote: some View {
        // 한마디가 없으면 따옴표도 그리지 않는다.
        // 빈 자리에 여는 따옴표와 닫는 따옴표만 남으면 무언가 지워진 것처럼 보인다.
        if !post.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            quoteBody
        }
    }

    private var quoteBody: some View {
        let lastLineTop = Self.quoteTextOrigin.y
            + CGFloat(quoteLines - 1) * Self.quoteLineHeight

        return ZStack(alignment: .topLeading) {
            // 폭을 넘기면 줄을 나눈다.
            // 폭을 주지 않으면 한 줄에 우겨넣다가 「...」로 잘린다.
            BakedLineHeightText(
                post.text,
                font: .doodleHandwriting(size: Self.quoteFontSize),
                lineHeight: Self.quoteLineHeight,
                color: Self.quoteColor,
                tracking: Self.quoteTracking,
                width: Self.quoteTextSize.width,
                maxLines: Self.maxQuoteLines
            )
            .frame(width: Self.quoteTextSize.width)
            .offset(x: Self.quoteTextOrigin.x, y: Self.quoteTextOrigin.y)

            // 따옴표는 글과 함께 움직인다. 여는 쪽은 첫 줄, 닫는 쪽은 **마지막 줄**에 선다.
            mark(at: CGPoint(x: Self.openMarkOrigin.x,
                             y: Self.quoteTextOrigin.y + Self.openMarkRise),
                 flipped: false)
            mark(at: CGPoint(x: closeMarkLeft, y: lastLineTop), flipped: true)
        }
    }

    /// 닫는 따옴표의 왼쪽.
    ///
    /// **Figma 자리(304)에 서되, 글이 길면 비켜난다.**
    ///
    /// 최종시안의 예시 한마디는 마지막 줄이 277 에서 끝나 따옴표와 27 이 벌어진다.
    /// 그런데 글상자는 335 까지 쓸 수 있어, 한마디가 조금만 길면 마지막 줄이 따옴표 자리를 지난다.
    /// 그때는 글 끝에서 `closeMarkGap` 만큼 물러난 자리에 선다.
    ///
    /// **마지막 줄만 보면 된다.** 예전 따옴표는 80pt 글리프를 34 짜리 칸에 담은 것이라
    /// 획이 한 줄 위까지 올라가 윗줄까지 피해야 했는데, 지금 것은 21x18 짜리 그림이라
    /// 30 짜리 줄 안에 얌전히 들어앉는다.
    private var closeMarkLeft: CGFloat {
        let font = UIFont.doodleHandwriting(size: Self.quoteFontSize)
        let lines = BakedLineHeightText.wrapped(post.text,
                                                font: font,
                                                width: Self.quoteTextSize.width,
                                                tracking: Self.quoteTracking)
        let attributes = BakedLineHeightText.attributes(font: font, tracking: Self.quoteTracking)
        // 글이 가운데 정렬이라 마지막 줄은 글상자 한가운데에 놓인다.
        let lastWidth = (lines.last as NSString?)?.size(withAttributes: attributes).width ?? 0
        let lastRight = Self.quoteTextOrigin.x + (Self.quoteTextSize.width + lastWidth) / 2

        return min(max(Self.closeMarkOrigin.x, lastRight + Self.closeMarkGap), Self.closeMarkLimit)
    }

    /// 한마디가 차지하는 줄 수. 넘치면 `maxQuoteLines` 에서 끊긴다.
    private var quoteLines: Int {
        let counted = BakedLineHeightText.lineCount(
            post.text,
            font: .doodleHandwriting(size: Self.quoteFontSize),
            width: Self.quoteTextSize.width,
            tracking: Self.quoteTracking
        )
        return min(max(counted, 1), Self.maxQuoteLines)
    }

    /// 따옴표 한 개.
    ///
    /// 닫는 쪽은 **좌우로 뒤집는다.**
    /// Figma 는 `-scale-y-100` 과 `rotate-180` 을 함께 걸어 두었는데,
    /// 위아래 반전과 180도 회전을 합치면 결국 좌우 반전이다.
    private func mark(at origin: CGPoint, flipped: Bool) -> some View {
        Image(.exportQuoteMark)
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(Self.markColor)
            .frame(width: Self.markSize.width, height: Self.markSize.height)
            .scaleEffect(x: flipped ? -1 : 1, y: 1)
            .offset(x: origin.x, y: origin.y)
            .accessibilityHidden(true)
    }

    // MARK: - 자리 (최종시안 `424:792` · `424:863`)

    /// 캔버스가 들어가는 상자. `Rectangle 8` 이 (57, 235) 에 288x314.
    private static let canvasBox = CGRect(x: 57, y: 235, width: 288, height: 314)

    /// 상자 안에서 캔버스가 실제로 차지하는 크기.
    ///
    /// 캔버스(350x390)와 상자(288x314)의 비가 달라 그대로 늘리면 그림이 찌그러진다.
    /// 세로가 먼저 차므로 높이는 314 그대로고 폭이 281.8 로 줄어든다.
    private static let drawingSize: CGSize = {
        let canvas = DoodleMetrics.canvasSize
        let scale = min(canvasBox.width / canvas.width, canvasBox.height / canvas.height)
        return CGSize(width: canvas.width * scale, height: canvas.height * scale)
    }()
    /// 상자 한가운데에 놓는다.
    private static let drawingOrigin = CGPoint(
        x: canvasBox.midX - drawingSize.width / 2,
        y: canvasBox.midY - drawingSize.height / 2
    )

    /// 한마디 글상자. `424:883` 이 (101, 566) 에 234 폭, 손글씨체 28 · 행높이 30 · 자간 -1.12.
    private static let quoteTextOrigin = CGPoint(x: 101, y: 566)
    private static let quoteTextSize = CGSize(width: 234,
                                              height: quoteLineHeight * CGFloat(maxQuoteLines))
    private static let quoteFontSize: CGFloat = 28
    private static let quoteLineHeight: CGFloat = 30
    private static let quoteTracking: CGFloat = -1.12
    /// Figma `#272727`. 제목(`#424242`)보다 진하다 — 손글씨 본문이라 또렷해야 읽힌다.
    private static let quoteColor = Color(red: 0x27 / 255, green: 0x27 / 255, blue: 0x27 / 255)

    /// 담을 수 있는 최대 줄 수.
    ///
    /// **둘이면 넉넉하다.** 한마디는 30자까지고(`DrawingPage.textLimit`),
    /// 234 짜리 글상자 두 줄이면 468 을 담는다.
    /// 셋으로 늘리면 꼬리말(683)까지 흘러내린다.
    private static let maxQuoteLines = 2

    /// 따옴표. `424:884` 가 (72, 557), `424:885` 가 (304, 596) 에 21x18.
    private static let markSize = CGSize(width: 21, height: 18)
    private static let openMarkOrigin = CGPoint(x: 72, y: 557)
    private static let closeMarkOrigin = CGPoint(x: 304, y: 596)
    /// 여는 따옴표가 첫 줄보다 얼마나 위에 서는지. 566 - 557.
    private static let openMarkRise: CGFloat = -9
    /// 마지막 글자와 닫는 따옴표 사이.
    private static let closeMarkGap: CGFloat = 8
    /// 닫는 따옴표가 물러날 수 있는 오른쪽 끝. 캔버스 상자의 오른쪽 선(345)을 넘지 않는다.
    private static let closeMarkLimit = canvasBox.maxX - markSize.width
    /// Figma `#B0B0B0`.
    private static let markColor = Color(white: 0xB0 / 255)
}
