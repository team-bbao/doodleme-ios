//
//  Font+Doodle.swift
//  DoodleMe
//

import SwiftUI

/// 앱이 직접 들고 다니는 글꼴.
extension Font {
    /// 카드 뒷면 한마디에 쓰는 손글씨체.
    /// Figma `iPhone 17 - 14` 의 `Frame 35`(92:828) 가 쓰는 `RF대충쓴준우체v3`.
    ///
    /// 넘기는 이름은 파일명이 아니라 PostScript 이름(`RFjunwooo`)이다.
    /// 파일은 `Resources/Fonts/RFjunwooo.ttf` 에 있고 `Info.plist` 의 `UIAppFonts` 에 등록돼 있다.
    /// 글꼴을 못 찾으면 SwiftUI 가 알아서 시스템 글꼴로 떨어지므로 화면이 비지는 않는다.
    ///
    /// `fixedSize` 를 쓴다. 카드가 362x396 으로 못박혀 있어 글자가 커지면
    /// 한마디가 카드 밖으로 밀려난다. 앱의 다른 글자도 모두 고정 크기다.
    static func doodleHandwriting(size: CGFloat) -> Font {
        .custom("RFjunwooo", fixedSize: size)
    }
}
