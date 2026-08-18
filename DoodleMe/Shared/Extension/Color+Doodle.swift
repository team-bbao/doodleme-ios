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

    /// 세그먼트 트랙 바탕. Figma `#F0F0F0`
    static let doodleSegmentTrack = Color(red: 0xF0 / 255, green: 0xF0 / 255, blue: 0xF0 / 255)
    /// 선택된 세그먼트 라벨. Figma `#212121`
    static let doodleSegmentSelected = Color(red: 0x21 / 255, green: 0x21 / 255, blue: 0x21 / 255)
    /// 선택되지 않은 세그먼트 라벨. Figma `#6A6A6A`
    static let doodleSegmentUnselected = Color(red: 0x6A / 255, green: 0x6A / 255, blue: 0x6A / 255)

    /// 보조 문구("님에게" 등). Figma `#6F6F6F`
    static let doodleSecondary = Color(red: 0x6F / 255, green: 0x6F / 255, blue: 0x6F / 255)
    /// 아바타 원 테두리. Figma `#E1E1E1`
    static let doodleHairline = Color(red: 0xE1 / 255, green: 0xE1 / 255, blue: 0xE1 / 255)
    /// 버튼 눌림 배경. Figma `rgba(121,121,121,0.1)`
    static let doodlePressed = Color(red: 121 / 255, green: 121 / 255, blue: 121 / 255).opacity(0.1)
}
