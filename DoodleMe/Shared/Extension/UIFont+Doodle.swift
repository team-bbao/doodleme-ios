//
//  UIFont+Doodle.swift
//  DoodleMe
//

import UIKit

/// 앱이 직접 들고 다니는 글꼴.
extension UIFont {
    /// 카드 뒷면 한마디에 쓰는 손글씨체.
    /// Figma `iPhone 17 - 14` 의 `Frame 35`(92:828) 가 쓰는 `RF대충쓴준우체v3`.
    ///
    /// 넘기는 이름은 파일명이 아니라 PostScript 이름(`RFjunwooo`)이다.
    /// 파일은 `Resources/Fonts/RFjunwooo.ttf` 에 있고 `Info.plist` 의 `UIAppFonts` 에 등록돼 있다.
    /// 못 찾으면 시스템 글꼴로 떨어져 화면이 비지는 않는다.
    ///
    /// 출처를 밝히면 상업적으로 쓸 수 있는 글꼴이다.
    /// 사용자가 볼 수 있는 자리에 출처를 적어야 한다 — README 의 「에셋」 참고.
    ///
    /// `UIFont` 인 이유는 행높이 때문이다.
    /// 이 글꼴은 세로 여백이 넉넉해 30pt 에서 기본 행높이가 73 이나 되는데,
    /// 디자인이 정한 44 로 줄이려면 SwiftUI `Text` 로는 안 되고 `UILabel` 을 빌려야 한다.
    /// 자세한 사정은 `FixedLineHeightText` 에 적어 두었다.
    static func doodleHandwriting(size: CGFloat) -> UIFont {
        UIFont(name: "RFjunwooo", size: size) ?? .systemFont(ofSize: size)
    }
}
