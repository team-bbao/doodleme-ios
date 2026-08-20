//
//  Font+Doodle.swift
//  DoodleMe
//

import SwiftUI

/// 앱이 직접 들고 다니는 글꼴 — SwiftUI 쪽.
extension Font {
    /// 카드 뒷면 한마디에 쓰는 손글씨체.
    ///
    /// 글을 쓰는 동안에도 저장한 뒤와 같은 글씨로 보이도록 입력란에도 같은 걸 쓴다.
    /// 넘기는 이름은 파일명이 아니라 PostScript 이름(`RFjunwooo`)이다.
    ///
    /// 행높이까지 정해야 하는 자리에는 이걸 쓰지 않는다.
    /// 이 글꼴은 세로 여백이 넉넉해 SwiftUI `Text` 로는 행높이가 잡히지 않는다.
    /// 그런 자리는 `UIFont.doodleHandwriting` 과 `FixedLineHeightText` 를 쓴다.
    static func doodleHandwriting(size: CGFloat) -> Font {
        .custom("RFjunwooo", size: size)
    }
}
