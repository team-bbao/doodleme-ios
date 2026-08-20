//
//  UIFont+Doodle.swift
//  DoodleMe
//

import SwiftUI
import UIKit

/// 앱이 직접 들고 다니는 글꼴.
extension UIFont {
    /// 손으로 쓴 한마디에 쓰는 글꼴. `캘리폰트 하루일기 젤리펜` Medium.
    ///
    /// 쓰는 자리는 두 곳이고, 같은 글이 두 곳을 지난다.
    /// 그리기 화면에서 입력할 때와, 카드 뒷면에서 다시 읽을 때다.
    ///
    /// 넘기는 이름은 파일명이 아니라 PostScript 이름(`CallifontDaynoteJellypen-Medium`)이다.
    /// 파일은 `Resources/Fonts/CallifontDaynoteJellypen-Medium.ttf` 에 있고 `Info.plist` 의 `UIAppFonts` 에 등록돼 있다.
    /// 못 찾으면 시스템 글꼴로 떨어져 화면이 비지는 않는다.
    ///
    /// 배포 조건은 아직 확인하지 않았다.
    /// 출처를 밝혀야 하는 글꼴이면 사용자가 볼 수 있는 자리에 적어야 한다 — README 의 「에셋」 참고.
    ///
    /// `UIFont` 인 이유는 행높이 때문이다.
    /// 손글씨체는 세로 여백이 넉넉해 기본 행높이가 지정값보다 한참 크다.
    /// 디자인이 정한 44 로 줄이려면 SwiftUI `Text` 로는 안 되고 `UILabel` 을 빌려야 한다.
    /// 자세한 사정은 `FixedLineHeightText` 에 적어 두었다.
    /// PostScript 이름. 파일명(`CallifontDaynoteJellypen-Medium.ttf`)과 우연히 같지만 다른 것이다.
    static let doodleHandwritingName = "CallifontDaynoteJellypen-Medium"

    static func doodleHandwriting(size: CGFloat) -> UIFont {
        UIFont(name: doodleHandwritingName, size: size) ?? .systemFont(ofSize: size)
    }
}

/// 같은 글꼴을 SwiftUI 쪽에서도 쓴다.
///
/// 행높이를 눌러야 하는 자리(카드 뒷면)만 `UIFont` 를 거치고,
/// 그냥 글꼴만 바꾸면 되는 자리는 이쪽을 쓴다.
extension Font {
    /// 이름은 `UIFont.doodleHandwriting(size:)` 과 같은 PostScript 이름이다.
    /// 한쪽만 고치면 두 자리의 글씨가 갈라지므로 이름을 한곳에서 가져다 쓴다.
    static func doodleHandwriting(size: CGFloat) -> Font {
        .custom(UIFont.doodleHandwritingName, size: size)
    }
}
