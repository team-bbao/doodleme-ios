//
//  ExportCard.swift
//  DoodleMe
//

import SwiftUI

/// 밖으로 내보내는 카드 한 장.
///
/// Figma 최종시안 `최종시안`(`424:2528`) 의 `IG Stories/User default` 다섯 장이 같은 틀을 쓴다 —
/// 종이 배경, 손글씨 제목 두 줄, 가운데 내용, 맨 아래 꼬리말, 그리고 종이 위를 가로지르는 낙서 셋.
/// 달라지는 것은 가운데뿐이라 그 자리를 `content` 로 비워 두고 카드들이 나눠 쓴다.
///
/// **좌표를 402x844 에 못박는다.**
/// 기기마다 다른 크기로 구우면 내보낸 이미지가 사람마다 달라진다.
/// 화면에 보일 때만 `scaleEffect` 로 줄이고, 안쪽 좌표는 어디서나 같다.
///
/// Figma 프레임에는 상태바(`Status bar - iPhone`)가 올려져 있는 판도 있지만 여기서는 그리지 않는다.
/// 그건 「아이폰 화면처럼 보이게」 하려고 얹은 목업이라, 그대로 구우면
/// 남의 인스타에 가짜 9시 41분이 박힌 이미지가 올라간다.
struct ExportCard<Content: View>: View {

    let title: ExportCardTitle
    /// 제목 블록의 윗변. **카드마다 다르다** — 한 장은 132, 격자는 104.
    /// 격자는 여섯 장을 담느라 제목이 위로 올라간다.
    var titleTop: CGFloat = ExportCardLayout.singleTitleTop
    @ViewBuilder var content: Content

    /// 이 카드를 얼마나 넓게 그릴지. 기본은 도안 칸(390)이다.
    ///
    /// **인스타그램 스토리로 보낼 때만 9:16(474.75)으로 넓힌다.**
    /// 스토리 편집기는 9:16 을 받으므로, 도안 칸 그대로 보내면 위아래를 잘리거나
    /// 좌우에 띠가 생긴다. 넓히는 것은 **종이뿐**이고 안쪽 구성(402 좌표계)은 그대로다 —
    /// 화면에서 보던 것과 스토리에 올라가는 것이 같은 그림으로 남는다.
    @Environment(\.exportCardWidth) private var cardWidth

    var body: some View {
        let size = CGSize(width: cardWidth, height: ExportCardLayout.size.height)
        let contentLeft = (cardWidth - ExportCardLayout.contentWidth) / 2

        return ZStack(alignment: .topLeading) {
            // 종이가 카드 전체를 덮는다. Figma 도 프레임(402)보다 넓게 x -70 에서 621 폭으로
            // 깔아 두었다 — 카드 폭 390 이 그 안에 넉넉히 들어간다.
            //
            // 화면용 `PaperBackground` 를 쓰지 않는다.
            // 그건 `GeometryReader` + `.ignoresSafeArea()` 라 **화면**을 채우도록 만든 것이라,
            // 크기가 못박힌 카드 안에서는 프레임 위로 새어 나간다 — 재 보니 위로 20 쯤 넘쳤다.
            // 카드는 어디에 놓이든 같은 크기여야 하므로 직접 크기를 준다.
            Image(.papertype1)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipped()
                .accessibilityHidden(true)

            // Figma 의 402 폭 구성은 **좌표를 하나도 건드리지 않고** 가운데에 놓는다.
            // 카드(390)가 그보다 좁아 좌우가 6 씩 잘린다 — Figma 도 똑같이 잘라 두었다.
            ZStack(alignment: .topLeading) {
                title
                    .frame(width: ExportCardLayout.contentWidth, alignment: .center)
                    .offset(y: titleTop)

                content

                footer
                    .frame(width: ExportCardLayout.contentWidth, alignment: .center)
                    .offset(y: ExportCardLayout.footerTop)

                // 낙서는 **맨 위에** 얹는다. Figma 도 402 프레임 바깥에 세 장을 쌓아 두었다.
                // 10~15% 짜리 검정이라 덮는 것이 아니라 종이를 물들이는 정도다 —
                // 아래에 깔면 제목·그림 뒤로 숨어 사라진다.
                paperDoodles
            }
            .frame(width: ExportCardLayout.contentWidth,
                   height: size.height,
                   alignment: .topLeading)
            .offset(x: contentLeft)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    /// 어느 화면에나 같은 문구로 맨 아래에 선다.
    ///
    /// 이 줄이 내보내기의 목적이다 — 받아 본 사람을 앱으로 데려온다.
    ///
    /// Figma `424:796`: SF 가 아니라 손글씨체 17, 행높이 20, `#424242`, 가운데.
    ///
    /// **가장 가는 굵기를 쓴다.** 이 줄은 카드에서 맨 나중에 읽혀야 하는 글이다 —
    /// 그림과 한마디를 다 보고 나서 「아, 이런 앱이구나」 하면 된다.
    /// 도안이 제목과 같은 굵기인 것은 그때 굵기가 한 벌뿐이었기 때문이지 같게 두려던 것이 아니다.
    /// 제목 `bold` · 한마디 `medium` · 꼬리말 `thin` 으로 세 단을 두어 읽는 차례를 만든다.
    private var footer: some View {
        BakedLineHeightText(
            "너도 친구의 첫인상을 그려봐.\n@doodle.me",
            font: .doodleHandwriting(size: ExportCardLayout.footerFontSize, weight: .thin),
            lineHeight: ExportCardLayout.footerLineHeight,
            color: .doodlePrimary
        )
    }

    /// 종이 위를 가로지르는 낙서 셋. Figma `Vector 47`·`48`·`49`.
    ///
    /// **종이 질감과 따로 있는 그림이다.** 질감(`paper texture 2`)에는 이 획이 없고,
    /// 디자이너가 그 위에 옅은 검정으로 세 획을 따로 그어 두었다.
    /// 종이만 깔면 카드가 허옇게 비어 보이는데, 이 획들이 빈 자리를 메운다.
    ///
    /// 셋 다 Figma 에서는 **390 짜리 스토리 칸** 기준으로 놓여 있다.
    /// 우리 좌표계는 그 안에 가운데로 든 402 프레임이라 x 를 6 씩 옮겨 적었다.
    private var paperDoodles: some View {
        ZStack(alignment: .topLeading) {
            doodle(.exportPaperDoodle1, opacity: 0.10,
                   box: CGRect(x: -8, y: 664, width: 289.629, height: 103.7),
                   ink: CGSize(width: 284.516, height: 84.412),
                   art: CGRect(x: -3.756, y: -8.98, width: 288.616, height: 99.4484),
                   degrees: 3.93, mirrored: false)

            doodle(.exportPaperDoodle2, opacity: 0.15,
                   box: CGRect(x: 169.33, y: -110.54, width: 330.667, height: 460.847),
                   ink: CGSize(width: 121.606, height: 460.01),
                   art: CGRect(x: -2.761, y: -1.012, width: 133.128, height: 468.832),
                   degrees: -29.22, mirrored: true)

            doodle(.exportPaperDoodle3, opacity: 0.10,
                   box: CGRect(x: -10, y: 330, width: 176.816, height: 346.468),
                   ink: CGSize(width: 176.816, height: 346.468),
                   art: CGRect(x: 0.46, y: -4.677, width: 183.013, height: 352.947),
                   degrees: 180, mirrored: true)
        }
        .accessibilityHidden(true)
    }

    /// 낙서 한 획.
    ///
    /// Figma 가 획 하나를 세 겹으로 적어 둔다 —
    /// `box` 는 **돌리고 난 뒤의** 테두리, `ink` 는 돌리기 전 그림의 크기,
    /// `art` 는 그 안에서 SVG 가 실제로 그려지는 자리다(획이 테두리 밖으로 조금 삐져나온다).
    /// 돌림은 그림의 한가운데를 축으로 도므로 `box` 의 한가운데에 `ink` 를 놓고 돌린다.
    ///
    /// 투명도를 SVG 가 아니라 여기서 먹인다. 에셋 카탈로그의 SVG 는 `fill-opacity` 를
    /// 제대로 읽지 못할 때가 있어, 획은 검정 그대로 두고 뷰에서 옅게 만든다.
    private func doodle(_ image: ImageResource,
                        opacity: Double,
                        box: CGRect,
                        ink: CGSize,
                        art: CGRect,
                        degrees: Double,
                        mirrored: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: ink.width, height: ink.height)

            Image(image)
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(.black)
                .frame(width: art.width, height: art.height)
                .offset(x: art.minX, y: art.minY)
        }
        .frame(width: ink.width, height: ink.height, alignment: .topLeading)
        // Figma 는 `rotate(...) scaleY(-1)` 순서로 적는다 — 뒤집고 나서 돌린다.
        // SwiftUI 도 아래에 붙인 것이 먼저 걸리므로 같은 차례가 된다.
        .scaleEffect(x: 1, y: mirrored ? -1 : 1)
        .rotationEffect(.degrees(degrees))
        .opacity(opacity)
        .offset(x: box.midX - ink.width / 2, y: box.midY - ink.height / 2)
    }
}

/// 카드의 자리값. Figma 최종시안 `424:2528` 에서 그대로 옮겨 왔다.
///
/// 제네릭인 `ExportCard` 안에는 `static let` 을 둘 수 없어 따로 뺐다.
/// 덕분에 `ExportCard<EmptyView>.size` 같은 군더더기 없이 어디서나 곧바로 가져다 쓴다.
///
/// 값이 전부 `static` 인 이유는 **카드가 언제나 한 크기**이기 때문이다.
/// 한때 스토리·게시물·프로필 세 판형을 굽느라 폭을 계산해 받았는데,
/// 인스타그램 스토리로만 내보내기로 하면서 그 갈래가 없어졌다.
enum ExportCardLayout {

    /// 카드 한 장의 크기. **Figma 최종시안 칸(`IG Stories/User default`) 그대로다.**
    ///
    /// 9:16 으로 넓히지 않는다. 스토리로 올릴 때의 비율은 인스타그램 편집기가 맡는다.
    /// 가로를 1080 에 맞춰 구우면 1080x2338 이 된다.
    static let size = CGSize(width: 390, height: contentHeight)

    /// 카드 안에서 402 짜리 도안이 시작하는 x. **-6 이다.**
    ///
    /// 카드(390)가 도안 프레임(402)보다 좁아 좌우가 6 씩 잘린다 —
    /// Figma 도 390 짜리 칸 안에 `iPhone 17 - 29` 를 x = -6 에 넣어 똑같이 잘라 놓았다.
    static let contentLeft: CGFloat = (size.width - contentWidth) / 2

    /// 인스타그램 스토리로 보낼 때의 폭. 9:16 이라 474.75 다.
    ///
    /// 메타 「스토리에 공유」 문서가 배경 이미지를 최소 720x1280, **9:16 또는 9:18** 로 두라고 한다.
    /// 도안 칸(390x844)은 9:19.5 라 그보다 길어, 그대로 보내면 편집기가 손을 댄다.
    static let storyWidth: CGFloat = contentHeight * 9 / 16

    /// 안쪽 구성이 쓰는 좌표계의 폭. **Figma `iPhone 17 - 29` 프레임 그대로다.**
    ///
    /// 디자인은 390 짜리 스토리 칸 안에 402 짜리 프레임을 가운데로 넣어 좌우를 6 씩 잘라 낸다.
    /// 우리도 402 를 카드 한가운데에 놓으므로 같은 자리가 된다.
    static let contentWidth: CGFloat = 402
    /// 카드 높이. **스토리 칸(844)이지 402 프레임의 871 이 아니다.**
    /// 디자인의 종이(845)도 844 에 맞춰 잘려 있고, 꼬리말 아래 여백도 844 를 기준으로 잡혀 있다.
    static let contentHeight: CGFloat = 844

    // MARK: - 세로 자리 (최종시안 `424:792` · `424:1795`)

    /// 제목 윗변. 한 장 카드(`424:797`)는 132, 격자 카드(`424:1823`)는 104.
    static let singleTitleTop: CGFloat = 132
    static let gridTitleTop: CGFloat = 104

    /// 꼬리말 윗변(`424:796`). 두 줄 x 20 이라 아랫변이 723, 카드 끝까지 121 이 남는다.
    static let footerTop: CGFloat = 683
    static let footerFontSize: CGFloat = 17
    static let footerLineHeight: CGFloat = 20

    /// 그림이 놓이는 띠의 위·아랫변.
    ///
    /// 최종시안의 여섯 칸은 줄 사이가 고르지 않다(165.8 / 148.9) — 손으로 흩어 놓은 자리라서다.
    /// 우리 격자는 고르게 나누므로, 줄 **한가운데**(454)가 맞도록 띠를 잡았다.
    /// 그러면 세 줄이 294.5 / 451.5 / 608.5 에 서서 도안(296.9 / 462.7 / 611.6)과
    /// 최대 11 안에서 겹친다. 아랫변은 꼬리말 윗변에서 끊어 글자를 침범하지 않는다.
    static let bodyTop: CGFloat = 220
    static let bodyBottom: CGFloat = footerTop
    static let bodyHeight: CGFloat = bodyBottom - bodyTop
}

/// 카드 맨 위의 두 줄 제목.
///
/// 「**에리카**가 그린 / **케빈**의 첫인상」 처럼 두 줄이고, **이름에만 밑줄**이 그어진다.
///
/// **진짜 Bold 로 굵게 쓴다.**
///
/// Figma 도안에서는 같은 글자를 1 씩 어긋나게 두세 겹 쌓아 굵게 만들어 두었다 —
/// 제목 아홉 군데가 전부 그렇다. 디자이너가 「해당 폰트가 굵기 조절이 없어서
/// 글씨체를 쌓았어요」 라고 적어 둔 그 수법이다.
///
/// 그런데 **굵기가 있었다.** 같은 글꼴에 Thin·Medium·Bold 세 벌이 따로 배포되고 있었고,
/// Bold 를 들여와 그대로 쓴다. 쌓기는 획을 가로로만 부풀려 가장자리가 두 겹으로 거칠어지는데,
/// 진짜 Bold 는 글자 모양 자체가 굵게 그려져 있어 획이 깨끗하다.
///
/// **이름과 나머지의 굵기를 더는 가르지 않는다.** 도안은 이름에만 한 겹을 더 얹었는데,
/// 그건 쌓기로 낼 수 있는 유일한 눈금이 「겹 수」 였기 때문이다.
/// Bold 위에 더 굵은 벌이 없고, 이름은 밑줄로 이미 갈라진다.
///
/// 밑줄은 Figma 의 SVG(손으로 그은 획)를 쓰지 않는다.
/// 그 그림은 「에리카」·「케빈」 이라는 **정해진 이름의 폭**에 맞춰 그려진 것이라,
/// 이름이 바뀌면 길이가 어긋난다. 글자 폭을 재서 직접 긋는다.
struct ExportCardTitle: View {

    /// 첫 줄에서 밑줄이 그어지는 부분. 보통 그린 사람 이름.
    let firstName: String
    /// 첫 줄에서 밑줄 없이 이어지는 부분. 예: 「가 그린」
    let firstTail: String
    /// 둘째 줄에서 밑줄이 그어지는 부분. 보통 그려진 사람 이름.
    let secondName: String
    /// 둘째 줄에서 밑줄 없이 이어지는 부분. 예: 「의 첫인상」
    let secondTail: String

    var body: some View {
        VStack(spacing: 0) {
            line(name: firstName, tail: firstTail)
            line(name: secondName, tail: secondTail)
        }
    }

    /// 한 줄. 이름과 나머지를 따로 그리는 이유는 굵기가 아니라 **밑줄** 때문이다 —
    /// 밑줄이 이름 폭만큼만 그어져야 해서 이름 조각의 폭을 따로 재야 한다.
    private func line(name: String, tail: String) -> some View {
        let shown = Self.fitted(name, tail: tail)

        return HStack(spacing: 0) {
            Text(shown)
            Text(tail)
        }
        .font(.doodleHandwriting(size: Self.fontSize, weight: .bold))
        .foregroundStyle(Color.doodlePrimary)
        .frame(height: Self.lineHeight)
        .overlay(alignment: .topLeading) { underline(under: shown) }
    }

    /// 이름 밑줄.
    ///
    /// `.underline()` 을 쓰지 않는다. 그건 글자에 바짝 붙고 두께도 글꼴이 정해 버려
    /// Figma 의 얇고 떨어진 선과 달라 보인다.
    ///
    /// Figma 는 밑줄을 글꼴 기능이 아니라 **따로 그린 벡터**(`Vector 42`·`43`·`44`)로 두었다.
    /// 그 그림은 정해진 이름 폭에 맞춰 그어진 것이라 그대로 쓸 수 없다 —
    /// 이름이 바뀌면 길이가 어긋난다. 그래서 글자 폭을 재서 같은 자리에 직접 긋는다.
    ///
    /// 최종시안 렌더에서 잰 값이다: 줄 윗변에서 34.4 / 33.4 / 31 아래, 색 `#646464`.
    private func underline(under name: String) -> some View {
        let font = UIFont.doodleHandwriting(size: Self.fontSize, weight: .bold)
        let width = (name as NSString).size(withAttributes: [.font: font]).width

        return Capsule()
            .fill(Self.underlineColor)
            .frame(width: width, height: Self.underlineThickness)
            .offset(y: Self.underlineTop)
    }

    /// 한 줄에 들어가도록 줄인 이름.
    ///
    /// **글자와 밑줄이 같은 것을 보게 하려고 여기서 한 번만 자른다.**
    /// 그냥 두면 `Text` 가 알아서 말줄임으로 자르는데 밑줄은 자르기 **전** 폭으로 그어진다 —
    /// 이름은 15자까지 쓸 수 있어 한글로 채우면 재 본 폭이 700 을 넘고,
    /// 자른 글자 밑에만 있어야 할 선이 「의 첫인상」 을 지나 카드 밖까지 뻗었다.
    /// 열다섯 자짜리 이름으로 구워서 확인했다.
    private static func fitted(_ name: String, tail: String) -> String {
        let font = UIFont.doodleHandwriting(size: fontSize, weight: .bold)
        let tailWidth = (tail as NSString).size(withAttributes: [.font: font]).width
        let available = max(ExportCardLayout.contentWidth - tailWidth, 0)

        guard (name as NSString).size(withAttributes: [.font: font]).width > available else {
            return name
        }

        var body = name
        while !body.isEmpty {
            let candidate = body + "…"
            if (candidate as NSString).size(withAttributes: [.font: font]).width <= available {
                return candidate
            }
            body.removeLast()
        }
        return ""
    }

    private static let fontSize: CGFloat = 40
    private static let lineHeight: CGFloat = 44

    /// 줄 윗변에서 밑줄까지. 최종시안 실측 34.4 / 33.4 / 31.
    private static let underlineTop: CGFloat = 34
    /// 밑줄 두께. 최종시안의 세 획이 3.4 · 0.985 · 4 로 제각각이라 — 손으로 그은 것이라서다 —
    /// 그 가운데를 잡았다. 2 로 두었더니 구운 카드에서 Figma 보다 눈에 띄게 가늘었다.
    private static let underlineThickness: CGFloat = 3
    /// Figma 실측 `#646464`. 글자(`#424242`)보다 연하다.
    private static let underlineColor = Color(red: 0x64 / 255, green: 0x64 / 255, blue: 0x64 / 255)
}
