//
//  ExportCard.swift
//  DoodleMe
//

import SwiftUI

/// 밖으로 내보내는 카드 한 장.
///
/// Figma `iPhone 17 - 26 / 27 / 28` 이 같은 틀을 쓴다 —
/// 종이 배경, 손글씨 제목 두 줄, 가운데 내용, 맨 아래 꼬리말.
/// 달라지는 것은 가운데뿐이라 그 자리를 `content` 로 비워 두고 세 화면이 나눠 쓴다.
///
/// **좌표를 402x871 에 못박는다.**
/// 기기마다 다른 크기로 구우면 내보낸 이미지가 사람마다 달라진다.
/// 화면에 보일 때만 `scaleEffect` 로 줄이고, 안쪽 좌표는 어디서나 같다.
///
/// Figma 프레임에는 상태바(`Status bar - iPhone`, 402x62)가 올려져 있지만 여기서는 그리지 않는다.
/// 그건 「아이폰 화면처럼 보이게」 하려고 얹은 목업이라, 그대로 구우면
/// 남의 인스타에 가짜 9시 41분이 박힌 이미지가 올라간다.
/// 대신 그 자리를 빈 종이로 남겨 제목 위 여백 106 을 Figma 그대로 지킨다.
struct ExportCard<Content: View>: View {

    let title: ExportCardTitle
    @ViewBuilder var content: Content

    /// 지금 굽는 판형. 좌우 폭만 여기에 달렸고 세로는 어느 판이든 같다.
    @Environment(\.exportRatio) private var ratio

    var body: some View {
        let layout = ExportCardLayout(ratio: ratio)

        return ZStack(alignment: .topLeading) {
            // 종이가 카드 전체를 덮는다. Figma 도 프레임(402)보다 넓게 x -70 에서 544 폭으로
            // 깔아 두었다 — 9:16 으로 넓힌 490 이 그 안에 들어간다.
            // 1:1(871)은 그보다 넓지만 종이는 늘어나는 무늬라 이어 붙여도 티가 나지 않는다.
            //
            // 화면용 `PaperBackground` 를 쓰지 않는다.
            // 그건 `GeometryReader` + `.ignoresSafeArea()` 라 **화면**을 채우도록 만든 것이라,
            // 크기가 못박힌 카드 안에서는 프레임 위로 새어 나간다 — 재 보니 위로 20 쯤 넘쳤다.
            // 카드는 어디에 놓이든 같은 크기여야 하므로 직접 크기를 준다.
            Image(.papertype1)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: layout.size.width, height: layout.size.height)
                .clipped()
                .accessibilityHidden(true)

            // Figma 의 402 폭 구성은 **좌표를 하나도 건드리지 않고** 가운데에 놓는다.
            // 판형을 만드느라 넓힌 좌우(9:16 은 각 44, 4:5 는 147, 1:1 은 235)는 종이만 이어진다.
            ZStack(alignment: .topLeading) {
                title
                    .frame(width: ExportCardLayout.contentWidth, alignment: .center)
                    .offset(y: ExportCardLayout.titleTop)

                content

                footer
                    .frame(width: ExportCardLayout.contentWidth, alignment: .center)
                    .offset(y: ExportCardLayout.footerTop)
            }
            .frame(width: ExportCardLayout.contentWidth,
                   height: layout.size.height,
                   alignment: .topLeading)
            .offset(x: layout.contentLeft)
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .clipped()
    }

    /// 어느 화면에나 같은 문구로 맨 아래에 선다.
    ///
    /// 이 줄이 내보내기의 목적이다 — 받아 본 사람을 앱으로 데려온다.
    private var footer: some View {
        BakedLineHeightText(
            "너도 친구의 첫인상을 그려봐.\n@doodle.me",
            font: .doodleHandwriting(size: 20),
            lineHeight: 20,
            color: .doodlePrimary
        )
    }
}

/// 카드의 자리값. Figma `iPhone 17 - 26 / 27 / 28` 에서 그대로 옮겨 왔다.
///
/// 제네릭인 `ExportCard` 안에는 `static let` 을 둘 수 없어 따로 뺐다.
/// 덕분에 `ExportCard<EmptyView>.size` 같은 군더더기 없이 어디서나 곧바로 가져다 쓴다.
///
/// **판형마다 폭만 달라진다.** 세로와 안쪽 좌표는 어느 판이든 같으므로
/// `titleTop` 처럼 세로에 매인 값은 그대로 `static` 이고,
/// 폭에 매인 `size`·`contentLeft` 만 판형을 받아 계산한다.
struct ExportCardLayout {

    /// 어느 자리에 올릴 판인지.
    let ratio: ExportRatio

    /// 카드 한 장의 크기.
    ///
    /// Figma 프레임은 402x871(1 : 2.167)이라 인스타그램이 그대로 받지 못한다.
    /// 피드는 4:5 까지, 스토리는 9:16 이라 올리면 위아래가 잘리거나 양옆에 검은 띠가 남는다.
    /// 실제로 구워 보니 피드에서 **위아래 각 21.2%** 가 날아가 제목과 「@doodle.me」 가 사라졌다.
    ///
    /// 그래서 세로는 Figma 그대로 두고 **좌우만 넓힌다.**
    /// 쓰는 판형 셋이 모두 Figma 원본보다 가로로 넓어(0.5625 · 0.8 · 1 > 0.4616)
    /// 같은 방법으로 셋 다 만들어진다 — 안쪽 구성은 402 좌표계에 그대로 있고
    /// 넓힌 자리는 종이만 이어지므로, Figma 초안이 한 군데도 바뀌지 않는다.
    ///
    /// 높이가 셋 다 871 로 같아서 구운 파일이 딱 떨어진다 —
    /// 1080x1920 · 1080x1350 · 1080x1080.
    var size: CGSize {
        CGSize(width: Self.contentHeight * ratio.value, height: Self.contentHeight)
    }

    /// 넓힌 카드 안에서 Figma 구성이 시작하는 x. 좌우로 똑같이 나눠 가진다.
    var contentLeft: CGFloat { (size.width - Self.contentWidth) / 2 }

    /// 안쪽 구성이 쓰는 좌표계의 폭. **9:16 카드의 폭 그대로다.**
    ///
    /// 한때 Figma 프레임 폭(402)을 그대로 썼는데, 그러면 정작 우리가 내보내는 9:16 카드
    /// 안에서 좌우로 44 씩이 맨 종이로 남았다 — 메모지 자신의 여백 28 까지 더해
    /// 한쪽에 72(카드 폭의 14.7%)가 비었다.
    /// Figma 에 9:16 도안이 없어 402 짜리 도안을 기준으로 삼았던 탓이다.
    ///
    /// 그래서 **가장 좁은 판형인 9:16 을 좌표계로 삼는다.** 넓은 판형(4:5 · 1:1)은
    /// 여기에 종이만 이어 붙인다. 세로 값은 Figma 그대로이므로 판형이 달라져도 흔들리지 않는다.
    static let contentWidth: CGFloat = contentHeight * ExportRatio.story.value
    /// Figma 프레임의 높이. 카드 높이가 곧 이것이다.
    static let contentHeight: CGFloat = 871

    // MARK: - 세로 격자
    //
    // 세 카드(한 장 · 격자 · 말풍선)가 **같은 격자**를 쓴다.
    // 값 셋만 정하고 나머지는 전부 여기서 끌어낸다 — 손으로 잡은 자리는 없다.
    //
    //     바깥 여백 45  ┌──────────────┐
    //                   │   제목 (획 76) │
    //         리듬 36   │               │
    //                   │   본문 598    │  <- 메모지 / 격자 / 말풍선
    //         리듬 36   │               │
    //                   │  꼬리말 (획 34) │
    //     바깥 여백 45  └──────────────┘
    //
    // Figma 402 도안은 위 112 · 아래 25 로 한쪽에 쏠려 있었다.
    // 402x871(1:2.167)에서는 알맞았지만 9:16 카드에 옮기니 위만 크게 비었다.
    // 위아래를 같게 두고 남은 자리를 본문에 몰아 준다.

    /// 좌우 여백. Figma 메모지가 쓰던 28 을 세 카드가 함께 쓴다.
    static let sideMargin: CGFloat = 28
    /// 위·아래 바깥 여백. 블록의 테두리가 아니라 **획**에서 카드 끝까지 잰다 —
    /// 제목 블록은 위쪽에 3.4 의 빈 줄을 물고 있어 블록으로 재면 위가 그만큼 좁아 보인다.
    static let outerMargin: CGFloat = 45
    /// 블록 사이 리듬. 제목-본문, 본문 안, 본문-꼬리말이 모두 이 간격이다.
    static let rhythm: CGFloat = 36

    /// 제목 블록(두 줄 x 44) 위에서 첫 획까지, 그리고 획의 높이.
    private static let titleInkTop: CGFloat = 3.4
    private static let titleInkHeight: CGFloat = 76.2
    /// 꼬리말 획(두 줄 x 20)의 높이. 블록 위에서 곧바로 획이 시작한다.
    private static let footerInkHeight: CGFloat = 34.4

    /// 제목 윗변. 획이 `outerMargin` 에 오도록 블록을 위로 물린다.
    static let titleTop: CGFloat = outerMargin - titleInkTop
    /// 꼬리말 윗변. 획의 아랫변이 카드 아래에서 `outerMargin` 만큼 떨어진다.
    static let footerTop: CGFloat = contentHeight - outerMargin - footerInkHeight

    /// 본문이 쓰는 자리의 윗변·아랫변. 제목과 꼬리말에서 리듬만큼 떨어진다.
    static let bodyTop: CGFloat = outerMargin + titleInkHeight + rhythm
    static let bodyBottom: CGFloat = footerTop - rhythm
    static let bodyHeight: CGFloat = bodyBottom - bodyTop
}

/// 카드 맨 위의 두 줄 제목.
///
/// 「**에리카**가 그린 / **케빈**의 첫인상」 처럼 두 줄이고, **이름에만 밑줄**이 그어진다.
///
/// Figma 는 같은 글자를 1px 어긋나게 두 번 겹쳐 그려 두었다.
/// 손글씨체에 Bold 가 없어 굵게 보이려던 수법인데, 여기서는 한 번만 그린다.
/// 접근성 도구가 같은 글을 두 번 읽는 것을 피하려는 것이다.
/// 구워 보고 너무 가늘면 획을 두껍게 하는 쪽으로 옮긴다.
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

    /// 한 줄. 이름 조각에만 밑줄을 깐다.
    ///
    /// Figma 는 같은 글자를 1px 어긋나게 두 번 겹쳐 그려 굵게 보이게 했다 —
    /// 손글씨체에 Bold 가 없어 쓴 수법이다. 한 번만 그리면 눈에 띄게 가늘어져 같게 맞춘다.
    /// 겹치는 쪽은 화면 낭독기에 숨겨 같은 글을 두 번 읽지 않게 한다.
    private func line(name: String, tail: String) -> some View {
        let shown = Self.fitted(name, tail: tail)
        let glyphs = HStack(spacing: 0) {
            Text(shown)
            Text(tail)
        }
        .font(.doodleHandwriting(size: Self.fontSize))
        .foregroundStyle(Color.doodlePrimary)

        return glyphs
            .overlay {
                glyphs
                    .offset(x: 1)
                    .accessibilityHidden(true)
            }
            .frame(height: Self.lineHeight)
            .overlay(alignment: .topLeading) { underline(under: shown) }
    }

    /// 이름 밑줄.
    ///
    /// `.underline()` 을 쓰지 않는다. 그건 글자에 바짝 붙고 두께도 글꼴이 정해 버려
    /// Figma 의 얇고 떨어진 선과 달라 보인다.
    ///
    /// Figma 는 밑줄을 글꼴 기능이 아니라 **따로 그린 벡터**(`Vector 42`·`Vector 43`)로 두었다.
    /// 그 그림은 「에리카」·「케빈」 이라는 정해진 이름 폭에 맞춰 그어진 것이라 그대로 쓸 수 없다 —
    /// 이름이 바뀌면 길이가 어긋난다. 그래서 글자 폭을 재서 같은 자리에 직접 긋는다.
    ///
    /// Figma 렌더에서 잰 값이다: 줄 윗변에서 34 아래, 두께 2, 색 `#646464`.
    private func underline(under name: String) -> some View {
        let font = UIFont.doodleHandwriting(size: Self.fontSize)
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
        let font = UIFont.doodleHandwriting(size: fontSize)
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

    /// 줄 윗변에서 밑줄까지. Figma 실측 첫 줄 +34, 둘째 줄 +33.
    private static let underlineTop: CGFloat = 34
    private static let underlineThickness: CGFloat = 2
    /// Figma 실측 `#646464`. 글자(`#424242`)보다 연하다.
    private static let underlineColor = Color(red: 0x64 / 255, green: 0x64 / 255, blue: 0x64 / 255)
}
