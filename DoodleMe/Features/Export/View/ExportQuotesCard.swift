//
//  ExportQuotesCard.swift
//  DoodleMe
//

import SwiftUI

/// 받은 한마디들을 말풍선으로 모아 내보내는 카드. Figma `iPhone 17 - 28`(`222:1845`).
///
/// 27번(그림 격자) 뒤에 붙는 장이다. 그림만으로는 남이 나를 어떻게 봤는지 읽히지 않는데,
/// 한마디는 그 말이 그대로 적혀 있어 읽는 사람에게 가장 먼저 가닿는다.
///
/// 제목이 「사람들이 **말하는**」 이라 27번의 「사람들이 **그린**」 과 한 쌍을 이룬다.
struct ExportQuotesCard: View {

    /// 이 장에 담을 것들. `paginate(_:)` 가 높이를 재서 미리 나눠 준다.
    let posts: [Post]
    /// 앱을 쓰는 나.
    let myName: String
    /// 내가 그린 것인지. 제목의 두 이름이 자리를 바꾼다 —
    /// 남들이 나를 그린 것은 「사람들이 말하는 / **케빈**의 첫인상」,
    /// 내가 남들을 그린 것은 「**케빈**이 말하는 / 사람들의 첫인상」.
    let mine: Bool

    /// 제목. 이름에만 밑줄이 그어지므로 이름이 어느 줄에 오는지에 따라 자리가 바뀐다.
    private var cardTitle: ExportCardTitle {
        mine
            ? ExportCardTitle(firstName: myName,
                              firstTail: "\(myName.subjectParticle) 말하는",
                              secondName: "",
                              secondTail: "사람들의 첫인상")
            : ExportCardTitle(firstName: "",
                              firstTail: "사람들이 말하는",
                              secondName: myName,
                              secondTail: "의 첫인상")
    }

    var body: some View {
        ExportCard(title: cardTitle) {
            bubbles
        }
    }

    // MARK: - 말풍선

    private var bubbles: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(laidOut.enumerated()), id: \.offset) { index, item in
                bubble(item.post, height: item.height, tailOnLeft: item.tailOnLeft)
                    .offset(x: Self.bodyLeft, y: item.top)
            }
        }
    }

    /// 말풍선 한 개. 몸통·글·따옴표가 한 덩이로 움직인다.
    private func bubble(_ post: Post, height: CGFloat, tailOnLeft: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            // 꼬리를 먼저 깔고 몸통을 위에 얹는다. Figma SVG 도 둘을 따로 두고 각각 그림자를 건다.
            // 한 Path 로 합치면 겹친 자리가 도로 뚫린다 — `SpeechBubbleTail` 주석 참고.
            //
            // 그림자는 Figma SVG 의 `feOffset dy=4` + `feGaussianBlur stdDeviation=10` + 검정 10%.
            // SwiftUI 반경은 CSS blur 의 절반이라 stdDeviation 과 같은 값이 된다.
            SpeechBubbleTail(tailOnLeft: tailOnLeft)
                .fill(.white)
                .frame(width: Self.bodyWidth, height: height)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)

            RoundedRectangle(cornerRadius: SpeechBubbleTail.cornerRadius)
                .fill(.white)
                .frame(width: Self.bodyWidth, height: height)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)

            BakedLineHeightText(
                post.text,
                font: .doodleHandwriting(size: Self.textSize),
                lineHeight: Self.lineHeight,
                color: .doodlePrimary,
                width: Self.textWidth
            )
            .frame(width: Self.textWidth, height: height - Self.padding * 2)
            .offset(x: (Self.bodyWidth - Self.textWidth) / 2, y: Self.padding)

            quoteMark(height: height, tailOnLeft: tailOnLeft)
        }
    }

    /// 따옴표. 꼬리와 **같은 쪽**에 붙는다.
    ///
    /// 왼쪽 꼬리에는 여는 따옴표가 왼쪽 위에, 오른쪽 꼬리에는 닫는 따옴표가 오른쪽 아래에 온다.
    /// 말이 시작하고 끝나는 자리를 꼬리가 가리키는 쪽과 맞춘 것이다 — Figma 셋 다 그렇다.
    ///
    /// 닫는 쪽은 **좌우로 뒤집는다.** `ExportSinglePostCard` 에 같은 기록이 있다.
    private func quoteMark(height: CGFloat, tailOnLeft: Bool) -> some View {
        Text("\u{201C}")
            .font(.custom(Self.quoteFontName, size: Self.quoteFontSize))
            .foregroundStyle(Self.quoteColor)
            .frame(width: Self.quoteSize.width, height: Self.quoteSize.height)
            .scaleEffect(x: tailOnLeft ? 1 : -1, y: 1)
            .offset(x: tailOnLeft
                    ? Self.quoteInset
                    : Self.bodyWidth - Self.quoteSize.width - Self.quoteInset,
                    y: tailOnLeft
                    ? Self.quoteTopInset
                    : height - Self.quoteSize.height - Self.quoteBottomInset)
    }

    // MARK: - 자리 잡기

    /// 말풍선 하나가 놓일 자리.
    private struct Placed {
        let post: Post
        let top: CGFloat
        let height: CGFloat
        /// 꼬리가 왼쪽인지. 왼·오·왼 으로 번갈아 붙는다.
        let tailOnLeft: Bool
    }

    /// 위에서부터 차례로 쌓는다. 높이가 제각각이라 자리를 미리 계산해 둔다.
    private var laidOut: [Placed] {
        var result: [Placed] = []
        var y = Self.contentTop
        for (index, post) in posts.enumerated() {
            let height = Self.bodyHeight(for: post)
            result.append(Placed(post: post, top: y, height: height,
                                 tailOnLeft: index.isMultiple(of: 2)))
            y += height + SpeechBubbleTail.tailDrop + Self.gap
        }
        return result
    }

    /// 글에 맞춘 몸통 높이.
    ///
    /// Figma 의 129.669(두 줄) · 187(세 줄)은 손으로 잡은 값이라 위아래 여백이 20.8 과 27.5 로
    /// 서로 다르다. 두 줄짜리 쪽을 따라 21 로 맞춘다 — 129.669 와 0.3 차이다.
    static func bodyHeight(for post: Post) -> CGFloat {
        let lines = BakedLineHeightText.lineCount(
            post.text,
            font: .doodleHandwriting(size: textSize),
            width: textWidth
        )
        return CGFloat(max(lines, 1)) * lineHeight + padding * 2
    }

    /// 한마디들을 한 장에 들어갈 만큼씩 나눈다.
    ///
    /// **한마디가 없는 그림은 빠진다.** 빈 말풍선은 할 말이 없다는 뜻이 아니라
    /// 그리기만 하고 넘어간 것이라, 남기면 읽는 사람에게 말줄임처럼 보인다.
    /// 고른 것이 전부 비어 있으면 빈 배열이 나오고, 그러면 이 장 자체가 만들어지지 않는다.
    ///
    /// 한 장에 세 개까지다(Figma 가 셋). 다만 긴 한마디가 겹치면 셋이 안 들어가므로
    /// 높이를 더해 보고 넘치면 거기서 끊는다.
    static func paginate(_ posts: [Post]) -> [[Post]] {
        let speaking = posts.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var pages: [[Post]] = []
        var page: [Post] = []
        var used: CGFloat = 0

        for post in speaking {
            let needed = bodyHeight(for: post) + SpeechBubbleTail.tailDrop
            let withGap = used + (page.isEmpty ? 0 : gap) + needed

            if !page.isEmpty, page.count >= maxPerPage || withGap > available {
                pages.append(page)
                page = []
                used = 0
            }

            used += (page.isEmpty ? 0 : gap) + needed
            page.append(post)
        }
        if !page.isEmpty { pages.append(page) }
        return pages
    }

    /// 한 장에 담는 최대 개수. Figma 가 셋을 둔다.
    static let maxPerPage = 3

    // MARK: - Figma 좌표

    /// 첫 말풍선 윗변. Figma `222:1889` 의 y.
    private static let contentTop: CGFloat = 227
    /// 말풍선 사이. 앞 꼬리 끝과 다음 몸통 윗변 사이가 Figma 에서 19.4 와 28.4 다. 그 가운데.
    private static let gap: CGFloat = 24
    /// 꼬리 끝까지 넣어 쓸 수 있는 세로 길이. 꼬리말(812) 앞에서 멈춘다.
    private static let available: CGFloat = 568

    /// Figma `Rectangle 4` 의 폭. 프레임(402) 가운데에 선다.
    private static let bodyWidth: CGFloat = 342
    private static let bodyLeft: CGFloat = (ExportCardLayout.contentWidth - bodyWidth) / 2

    /// 글이 들어갈 폭. Figma `222:1906` 이 302 — 좌우 20 씩 남긴 값이다.
    private static let textWidth: CGFloat = 302
    private static let textSize: CGFloat = 30
    private static let lineHeight: CGFloat = 44
    private static let padding: CGFloat = 21

    private static let quoteSize = CGSize(width: 42, height: 34)
    private static let quoteInset: CGFloat = 10
    /// 몸통 윗변에서 여는 따옴표까지. Figma 첫째·셋째 말풍선 모두 22.
    private static let quoteTopInset: CGFloat = 22
    /// 몸통 아랫변에서 닫는 따옴표까지. Figma 둘째 말풍선이 30.
    private static let quoteBottomInset: CGFloat = 30

    /// `ExportSinglePostCard` 와 같은 글꼴·색이다.
    private static let quoteFontName = "CrimsonText-Bold"
    private static let quoteFontSize: CGFloat = 80
    private static let quoteColor = Color(red: 0x7A / 255, green: 0x7A / 255, blue: 0x7A / 255)
}
