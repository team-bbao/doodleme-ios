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

    /// 지금 굽는 판형. 말풍선 폭이 여기에 달렸다.
    @Environment(\.exportRatio) private var ratio

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
                    .offset(x: Self.bodyLeft(for: ratio), y: item.top)
            }
        }
    }

    /// 말풍선 한 개. 몸통·글·따옴표가 한 덩이로 움직인다.
    private func bubble(_ post: Post, height: CGFloat, tailOnLeft: Bool) -> some View {
        let bodyWidth = Self.bodyWidth(for: ratio)
        let textWidth = Self.textWidth(for: ratio)

        return ZStack(alignment: .topLeading) {
            // 꼬리를 먼저 깔고 몸통을 위에 얹는다. Figma SVG 도 둘을 따로 두고 각각 그림자를 건다.
            // 한 Path 로 합치면 겹친 자리가 도로 뚫린다 — `SpeechBubbleTail` 주석 참고.
            //
            // 그림자는 Figma SVG 의 `feOffset dy=4` + `feGaussianBlur stdDeviation=10` + 검정 10%.
            // SwiftUI 반경은 CSS blur 의 절반이라 stdDeviation 과 같은 값이 된다.
            SpeechBubbleTail(tailOnLeft: tailOnLeft)
                .fill(.white)
                .frame(width: bodyWidth, height: height)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)

            RoundedRectangle(cornerRadius: SpeechBubbleTail.cornerRadius)
                .fill(.white)
                .frame(width: bodyWidth, height: height)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)

            BakedLineHeightText(
                post.text,
                font: .doodleHandwriting(size: Self.textSize),
                lineHeight: Self.lineHeight,
                color: .doodlePrimary,
                width: textWidth
            )
            .frame(width: textWidth, height: height - Self.padding * 2)
            .offset(x: (bodyWidth - textWidth) / 2, y: Self.padding)

            quoteMark(height: height, tailOnLeft: tailOnLeft, in: bodyWidth)
        }
    }

    /// 따옴표. 꼬리와 **같은 쪽**에 붙는다.
    ///
    /// 왼쪽 꼬리에는 여는 따옴표가 왼쪽 위에, 오른쪽 꼬리에는 닫는 따옴표가 오른쪽 아래에 온다.
    /// 말이 시작하고 끝나는 자리를 꼬리가 가리키는 쪽과 맞춘 것이다 — Figma 셋 다 그렇다.
    ///
    /// 닫는 쪽은 **좌우로 뒤집는다.** `ExportSinglePostCard` 에 같은 기록이 있다.
    private func quoteMark(height: CGFloat, tailOnLeft: Bool, in bodyWidth: CGFloat) -> some View {
        Text("\u{201C}")
            .font(.custom(Self.quoteFontName, size: Self.quoteFontSize))
            .foregroundStyle(Self.quoteColor)
            .frame(width: Self.quoteSize.width, height: Self.quoteSize.height)
            .scaleEffect(x: tailOnLeft ? 1 : -1, y: 1)
            .offset(x: tailOnLeft
                    ? Self.quoteInset
                    : bodyWidth - Self.quoteSize.width - Self.quoteInset,
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
    ///
    /// **몇 개가 들었든 첫 말풍선은 Figma 자리(227)에서 시작한다.**
    /// 한때는 덜 찬 쪽을 세로 가운데로 모았다 — 아래가 비어 보이지 않게 하려던 것인데,
    /// 그러면 장마다 첫 말풍선이 다른 높이에서 시작해 넘길 때 제목 아래가 들썩인다.
    /// 하나만 남은 장에서 특히 눈에 띄었다. 카드 여러 장을 이어 보는 자리라
    /// 장마다 같은 자리에서 시작하는 쪽이 낫다.
    private var laidOut: [Placed] {
        var result: [Placed] = []
        var y = Self.contentTop
        for (index, post) in posts.enumerated() {
            let height = Self.bodyHeight(for: post, ratio: ratio)
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
    static func bodyHeight(for post: Post, ratio: ExportRatio = .story) -> CGFloat {
        let lines = BakedLineHeightText.lineCount(
            post.text,
            font: .doodleHandwriting(size: textSize),
            width: textWidth(for: ratio)
        )
        return CGFloat(max(lines, 1)) * lineHeight + padding * 2
    }

    /// 한마디들을 한 장에 들어갈 만큼씩 나눈다.
    ///
    /// **한마디가 없는 그림은 빠진다.** 빈 말풍선은 할 말이 없다는 뜻이 아니라
    /// 그리기만 하고 넘어간 것이라, 남기면 읽는 사람에게 말줄임처럼 보인다.
    /// 고른 것이 전부 비어 있으면 빈 배열이 나오고, 그러면 이 장 자체가 만들어지지 않는다.
    ///
    /// **셋을 기본으로 두고, 글이 짧아 자리가 남으면 넷까지 받는다.**
    /// Figma 가 셋을 그렸지만 그건 예시 글이 두 줄씩일 때의 그림이다 —
    /// 한 줄짜리 한마디만 모이면 셋을 놓고도 종이 아래가 통째로 빈다.
    /// 거꾸로 긴 한마디가 겹치면 셋도 안 들어가므로, 어느 쪽이든 높이를 더해 보고 넘치면 끊는다.
    /// **쪽 나눔은 9:16 을 기준으로 잰다.**
    /// 판형마다 다르게 나누면 세그먼트를 건드릴 때마다 쪽수가 달라져 보던 자리를 잃는다.
    /// 넓은 판은 말풍선이 더 넓어 줄이 줄어들 뿐이라, 9:16 에서 들어간 것은 어디서나 들어간다.
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

        // 마지막 쪽에 하나만 남고 **앞 쪽이 넷까지 차 있으면** 하나를 넘겨 준다.
        //
        // 앞 쪽이 셋이면 넘기지 않는다. 넘기는 순간 Figma 가 그린 셋이 둘로 줄어드는데,
        // 그 둘뿐인 장이 내보내기의 얼굴이 된다 — 한마디 넷을 골랐더니 첫 장에 둘만 뜨는 것이
        // 바로 이 자리에서 나왔다. 마지막 장이 허전한 것보다 앞 장이 비는 것이 더 눈에 띈다.
        if pages.count >= 2, pages[pages.count - 1].count == 1,
           pages[pages.count - 2].count > figmaPerPage {
            let moved = pages[pages.count - 2].removeLast()
            pages[pages.count - 1].insert(moved, at: 0)
        }
        return pages
    }

    /// 한 장에 담는 최대 개수. 글이 짧아 자리가 남을 때만 여기까지 찬다.
    static let maxPerPage = 4
    /// Figma 가 그린 개수. 쪽을 나눌 때 앞 쪽에서 이만큼은 지킨다.
    static let figmaPerPage = 3

    // MARK: - Figma 좌표

    /// 첫 말풍선 윗변. Figma `222:1889` 의 y.
    private static let contentTop: CGFloat = 227
    /// 말풍선 사이. 앞 꼬리 끝과 다음 몸통 윗변 사이가 Figma 에서 19.4 와 28.4 다. 그 가운데.
    private static let gap: CGFloat = 24
    /// 꼬리 끝까지 넣어 쓸 수 있는 세로 길이. 꼬리말(812) 앞에서 멈춘다.
    ///
    /// Figma 의 셋째 말풍선은 꼬리 끝이 799.9 까지 내려오니 573 까지 줄 수도 있다.
    /// 그러지 않는 이유는 **5 를 더 줘도 들어가는 말풍선이 하나도 없기** 때문이다 —
    /// 말풍선 높이가 줄 수에 따라 44 씩 뛰어서 한 쪽의 총높이는 509.8 · 553.8 · 597.8 처럼
    /// 띄엄띄엄하고, 568 과 573 사이에 떨어지는 조합이 없다. 구워서 견줘 보니 한 장도 달라지지 않았다.
    /// 얻는 것 없이 꼬리말과의 여유만 17 에서 12 로 줄어든다.
    private static let available: CGFloat = 568

    /// 말풍선 몸통의 폭.
    ///
    /// Figma `Rectangle 4` 는 342 다 — 9:16 카드(490)의 70% 라 알맞게 찬다.
    /// 그런데 판형이 넓어져도 342 로 두면 1:1(871)에서는 **39%** 만 써서 좌우가 텅 빈다.
    /// 그래서 카드 폭에 비례해 넓히되 `maxBodyWidth` 에서 멈춘다 —
    /// 끝까지 늘리면 한 줄이 600 을 넘어, 손글씨로 읽기에 너무 긴 줄이 된다.
    static func bodyWidth(for ratio: ExportRatio) -> CGFloat {
        let card = ExportCardLayout(ratio: ratio).size.width
        let story = ExportCardLayout(ratio: .story).size.width
        return min(figmaBodyWidth * card / story, maxBodyWidth)
    }

    private static func bodyLeft(for ratio: ExportRatio) -> CGFloat {
        (ExportCardLayout.contentWidth - bodyWidth(for: ratio)) / 2
    }

    /// Figma `Rectangle 4` 의 폭.
    private static let figmaBodyWidth: CGFloat = 342
    /// 넓은 판에서 말풍선이 커지는 한계. 4:5 와 1:1 은 둘 다 여기서 멈춘다.
    private static let maxBodyWidth: CGFloat = 480

    /// 글이 들어갈 폭. 몸통에서 좌우 모서리의 따옴표 자리를 뺀 만큼이다.
    ///
    /// Figma 는 302(좌우 20 씩)를 쓰지만 그러면 **따옴표가 글자 위에 얹힌다.**
    /// 따옴표는 모서리에 붙어 x 10..52 와 290..332 를 차지하는데 302 짜리 글상자는 20..322 라
    /// 양쪽 32 씩이 겹친다. Figma 예시 글이 짧아 드러나지 않았을 뿐, 한 줄이 폭을 채우면
    /// 「같」 위에 닫는 따옴표가 그대로 포개진다 — 구워서 확인했다.
    /// 그래서 모서리를 비켜 간다.
    static func textWidth(for ratio: ExportRatio) -> CGFloat {
        bodyWidth(for: ratio) - (quoteInset + quoteSize.width) * 2
    }
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
