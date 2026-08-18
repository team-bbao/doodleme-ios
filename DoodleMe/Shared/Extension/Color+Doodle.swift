//
//  Color+Doodle.swift
//  DoodleMe
//

import SwiftUI

/// Figma 색상 스펙. 여러 화면에서 같은 값을 쓰므로 한곳에 모아둔다.
extension Color {
    /// 본문 · 제목. Figma `#424242`
    static let doodlePrimary = Color(red: 0x42 / 255, green: 0x42 / 255, blue: 0x42 / 255)
    /// 눌림 · 비활성. Figma `#929292`
    static let doodleMuted = Color(red: 0x92 / 255, green: 0x92 / 255, blue: 0x92 / 255)
    /// 세부정보. Figma `#828282`
    static let doodleDetail = Color(red: 0x82 / 255, green: 0x82 / 255, blue: 0x82 / 255)
}
