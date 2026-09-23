//
//  UIFont+Doodle.swift
//  DoodleMe
//

import SwiftUI
import UIKit

/// 손글씨체의 굵기. **읽는 차례를 굵기로 매긴다.**
///
/// 디자이너가 남긴 말이 이 타입의 이유다 —
/// 「해당 폰트가 굵기 조절이 없어서 글씨체를 쌓았어요… 그래야 가독성 조절이 이루어져서」.
/// 실은 같은 글꼴에 세 벌이 따로 배포되고 있었다. 셋을 다 들여 굵기를 손잡이로 꺼낸다.
///
/// **같은 크기라도 굵기가 다르면 읽는 차례가 갈린다.** 내보내기 카드에서는 이렇게 쓴다 —
///
///     제목    bold     맨 먼저 읽힌다
///     한마디  medium   그림에 딸린 말
///     꼬리말  thin     있는 줄만 알면 되는 말
///
/// **`.bold()` 같은 합성으로는 안 된다.** 세 벌이 서로 다른 패밀리로 등록돼 있어서다 —
/// Medium 은 패밀리가 「Callifont Daynote Jellypen Medium」 · 서브패밀리 Regular 이고
/// Bold 는 「Callifont Daynote Jellypen」 · 서브패밀리 Bold 다.
/// iOS 는 패밀리 안에서 굵기를 찾으므로, 굵게 해 달라고 하면 Medium 을 **억지로 부풀린**
/// 가짜 굵기를 만들어 낸다. 그래서 굵기마다 PostScript 이름을 직접 들고 있는다.
enum DoodleWeight {

    /// 물러나는 글. 꼬리말처럼 있는 줄만 알면 되는 자리.
    case thin
    /// 기본. 본문과 한마디.
    case medium
    /// 제목. 구운 카드에서 재면 획이 `medium` 의 1.24 배다.
    case bold

    /// PostScript 이름. 파일명과 우연히 같지만 다른 것이다.
    var fontName: String {
        switch self {
        case .thin: "CallifontDaynoteJellypen-Thin"
        case .medium: "CallifontDaynoteJellypen-Medium"
        case .bold: "CallifontDaynoteJellypen-Bold"
        }
    }
}

/// 앱이 직접 들고 다니는 글꼴.
extension UIFont {

    /// 손으로 쓴 글에 쓰는 글꼴. `캘리폰트 하루일기 젤리펜`.
    ///
    /// 파일은 `Resources/Fonts/` 에 굵기마다 한 벌씩 있고 `Info.plist` 의 `UIAppFonts` 에
    /// 셋 다 등록돼 있다. 못 찾으면 시스템 글꼴로 떨어져 화면이 비지는 않는다.
    ///
    /// **배포 조건을 확인했다**(callifont.com/product/daynote-jellypen, 2026-09-23).
    /// 무료 글꼴이고 모든 상업적 용도가 허용된다. 「임베딩 — 웹사이트 및 프로그램 서버 내
    /// 폰트 탑재」 가 허용이라 앱에 넣어 내보내는 지금 방식이 그대로 된다.
    /// 출처를 밝히라는 조건은 없다. 금지된 것은 **폰트 파일 자체**의 수정·복제·배포·유료 판매다 —
    /// 글꼴을 서브셋으로 깎거나 파일을 따로 내주는 일은 하지 않는다.
    ///
    /// `UIFont` 인 이유는 행높이 때문이다.
    /// 손글씨체는 세로 여백이 넉넉해 기본 행높이가 지정값보다 한참 크다.
    /// 디자인이 정한 44 로 줄이려면 SwiftUI `Text` 로는 안 되고 `UILabel` 을 빌려야 한다.
    /// 자세한 사정은 `FixedLineHeightText` 에 적어 두었다.
    static func doodleHandwriting(size: CGFloat, weight: DoodleWeight = .medium) -> UIFont {
        UIFont(name: weight.fontName, size: size) ?? .systemFont(ofSize: size)
    }
}

/// 같은 글꼴을 SwiftUI 쪽에서도 쓴다.
///
/// 행높이를 눌러야 하는 자리(카드 뒷면)만 `UIFont` 를 거치고,
/// 그냥 글꼴만 바꾸면 되는 자리는 이쪽을 쓴다.
extension Font {

    /// 이름은 `UIFont.doodleHandwriting(size:weight:)` 과 같은 곳(`DoodleWeight`)에서 가져온다.
    /// 한쪽만 고치면 두 자리의 글씨가 갈라진다.
    static func doodleHandwriting(size: CGFloat, weight: DoodleWeight = .medium) -> Font {
        .custom(weight.fontName, size: size)
    }
}
