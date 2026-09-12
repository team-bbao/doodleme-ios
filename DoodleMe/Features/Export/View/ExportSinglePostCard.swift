//
//  ExportSinglePostCard.swift
//  DoodleMe
//

import SwiftUI

/// 그림 한 장을 내보내는 카드. Figma `iPhone 17 - 26`(`222:1655`).
///
/// 받은 그림 한 장과 거기 딸린 한마디를 종이 위에 얹는다.
struct ExportSinglePostCard: View {

    let post: Post
    /// 그림을 받은 사람. 보통 앱을 쓰는 나다.
    let myName: String

    var body: some View {
        ExportCard(
            title: ExportCardTitle(
                firstName: post.displaySenderName,
                firstTail: "가 그린",
                secondName: myName,
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
    private var quote: some View {
        ZStack(alignment: .topLeading) {
            // 폭을 넘기면 줄을 나눈다.
            // 폭을 주지 않으면 한 줄에 우겨넣다가 「...」로 잘린다.
            BakedLineHeightText(
                post.text,
                font: .doodleHandwriting(size: 30),
                lineHeight: 44,
                color: .doodlePrimary,
                width: Self.quoteTextSize.width
            )
            .frame(width: Self.quoteTextSize.width)
            .offset(x: Self.quoteTextOrigin.x, y: Self.quoteTextOrigin.y)

            mark(at: Self.openQuoteOrigin, flipped: false)
            mark(at: Self.closeQuoteOrigin, flipped: true)
        }
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

    private static let quoteTextOrigin = CGPoint(x: 89, y: 644)
    private static let quoteTextSize = CGSize(width: 270, height: 88)
    private static let openQuoteOrigin = CGPoint(x: 40, y: 644)
    private static let closeQuoteOrigin = CGPoint(x: 354, y: 688)
    private static let quoteSize = CGSize(width: 42, height: 34)

    /// PostScript 이름. 파일은 `Resources/Fonts/CrimsonText-Bold.ttf`, `Info.plist` 의 `UIAppFonts` 에 등록돼 있다.
    private static let quoteFontName = "CrimsonText-Bold"
    private static let quoteFontSize: CGFloat = 80
    /// Figma `#7a7a7a`.
    private static let quoteColor = Color(red: 0x7A / 255, green: 0x7A / 255, blue: 0x7A / 255)
}
