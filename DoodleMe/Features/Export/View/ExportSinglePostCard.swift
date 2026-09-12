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

    /// 그림이 얹힌 종이. Figma `222:1759` (28, 238) 346x379.
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
                font: .doodleHandwriting(size: 30),
                lineHeight: Self.quoteLineHeight,
                color: .doodlePrimary,
                width: Self.quoteTextSize.width,
                maxLines: Self.maxQuoteLines
            )
            .frame(width: Self.quoteTextSize.width)
            .offset(x: Self.quoteTextOrigin.x, y: top)

            // 따옴표는 글과 함께 움직인다. 여는 쪽은 첫 줄, 닫는 쪽은 **마지막 줄**에 선다 —
            // Figma 도 두 줄짜리 예시에서 닫는 따옴표를 둘째 줄에 두었다(644 + 44 = 688).
            mark(at: CGPoint(x: Self.openQuoteOrigin.x, y: top), flipped: false)
            mark(at: CGPoint(x: Self.closeQuoteOrigin.x, y: lastLine), flipped: true)
        }
    }

    /// 한마디가 차지하는 줄 수. 넘치면 `maxQuoteLines` 에서 끊긴다.
    private var quoteLines: Int {
        let counted = BakedLineHeightText.lineCount(
            post.text,
            font: .doodleHandwriting(size: 30),
            width: Self.quoteTextSize.width
        )
        return min(max(counted, 1), Self.maxQuoteLines)
    }

    /// 한마디 첫 줄의 윗변.
    ///
    /// 두 줄까지는 Figma 자리(644) 그대로다. 그보다 길어지면 **위로 밀어 올린다** —
    /// 그러지 않으면 꼬리말(812) 자리로 흘러내린다. 네 줄짜리 한마디를 구워 보니
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

    // MARK: - Figma 좌표

    private static let memoOrigin = CGPoint(x: 28, y: 238)
    private static let memoSize = CGSize(width: 346, height: 379)

    private static let markOrigin = CGPoint(x: 37, y: 248)
    private static let markSide: CGFloat = 67

    /// 한마디 글상자. Figma 는 x 89 에서 폭 270 인데, 그러면 오른쪽 끝이 닫는 따옴표(354~396)와
    /// 겹친다. 따옴표 사이에 꼭 맞게 좁힌다 — 여는 쪽 끝(82)과 닫는 쪽 시작(354) 사이다.
    private static let quoteTextOrigin = CGPoint(x: 89, y: 644)
    private static let quoteTextSize = CGSize(width: 258, height: 88)
    private static let openQuoteOrigin = CGPoint(x: 40, y: 644)
    private static let closeQuoteOrigin = CGPoint(x: 354, y: 688)
    private static let quoteSize = CGSize(width: 42, height: 34)

    private static let quoteLineHeight: CGFloat = 44
    /// 한마디 띠의 아랫변. 꼬리말(812) 위로 16 을 남긴다.
    private static let quoteBandBottom: CGFloat = 796
    /// 한마디 띠의 윗변. 메모지 아랫변(238 + 379 = 617)에서 3 을 띄운다.
    private static let quoteBandTop: CGFloat = 620
    /// 담을 수 있는 최대 줄 수. 띠 높이를 행높이로 나눈 값이라 넷이다.
    /// 그보다 길면 말줄임표로 끊는다 — 꼬리말을 덮는 것보다 낫다.
    private static var maxQuoteLines: Int {
        Int((quoteBandBottom - quoteBandTop) / quoteLineHeight)
    }

    /// PostScript 이름. 파일은 `Resources/Fonts/CrimsonText-Bold.ttf`, `Info.plist` 의 `UIAppFonts` 에 등록돼 있다.
    private static let quoteFontName = "CrimsonText-Bold"
    private static let quoteFontSize: CGFloat = 80
    /// Figma `#7a7a7a`.
    private static let quoteColor = Color(red: 0x7A / 255, green: 0x7A / 255, blue: 0x7A / 255)
}
