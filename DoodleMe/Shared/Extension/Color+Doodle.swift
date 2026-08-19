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

    /// 제목 아래 붙는 보조 설명. Figma `#6A6A6A` (`iPhone 17 - 9` 의 안내 문구)
    static let doodleSubtext = Color(red: 0x6A / 255, green: 0x6A / 255, blue: 0x6A / 255)

    /// 갤러리 바탕. Figma `iPhone 17 - 14/15/16` 의 프레임 배경 `#F2F2F7`.
    ///
    /// 예전에는 종이 질감 이미지를 깔았는데, 최신 디자인이 평평한 색으로 바꿨다.
    /// iOS 의 systemGroupedBackground 와 같은 값이지만, 다크 모드에서도
    /// 디자인이 정한 이 색을 유지해야 하므로 시스템 색 대신 값을 못박는다.
    static let doodleBackground = Color(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF7 / 255)

    /// 무언가를 고르는 동안 뒤를 덮는 농도. Figma `iPhone 17 - 15` 의 `rgba(0,0,0,0.16)`
    static let doodleChoosingScrim = Color.black.opacity(0.16)
    /// 세그먼트에서 선택된 칸을 덮는 캡슐. Figma `iPhone 17 - 12` `#F1F1F1`
    static let doodleSegmentChip = Color(red: 0xF1 / 255, green: 0xF1 / 255, blue: 0xF1 / 255)
    /// 선택된 세그먼트 라벨. Figma `#212121`
    static let doodleSegmentLabel = Color(red: 0x21 / 255, green: 0x21 / 255, blue: 0x21 / 255)
    /// 확인창에서 물러나는 쪽 버튼 바탕.
    /// Figma 가 시스템 토큰 `fills/secondary` 를 그대로 쓰므로 우리도 같은 것을 쓴다.
    static let doodleControlFill = Color(uiColor: .secondarySystemFill)
    /// 확인창 테두리. Figma `iPhone 17 - 16` `#DBDBDB`
    static let doodlePopupBorder = Color(red: 0xDB / 255, green: 0xDB / 255, blue: 0xDB / 255)
    /// 카드 툴바에서 눌린 버튼 바탕. Figma `iPhone 17 - 14` `#E4E4E5`
    static let doodleCardToolbarPressed = Color(red: 0xE4 / 255, green: 0xE4 / 255, blue: 0xE5 / 255)
    /// 화면 제목. Figma 라지 타이틀 `#1A1A1A`
    static let doodleTitle = Color(red: 0x1A / 255, green: 0x1A / 255, blue: 0x1A / 255)

    /// 보조 문구("님에게" 등). Figma `#6F6F6F`
    static let doodleSecondary = Color(red: 0x6F / 255, green: 0x6F / 255, blue: 0x6F / 255)
    /// 아바타 원 테두리. Figma `#E1E1E1`
    static let doodleHairline = Color(red: 0xE1 / 255, green: 0xE1 / 255, blue: 0xE1 / 255)
    /// 접혀 올라온 뒷면 색. 본체보다 한 톤 어둡다. 역시 에셋에서 뽑았다.
    static let doodleFoldFlap = Color(red: 0xEF / 255, green: 0xEF / 255, blue: 0xEF / 255)
    /// 메모지 본체 색. 에셋에서 직접 뽑은 값이라 카드 앞뒤가 정확히 같아진다.
    static let doodlePaper = Color(red: 0xFA / 255, green: 0xFA / 255, blue: 0xFA / 255)
    /// 메모지에서 빛을 받는 쪽. `memoBack` 에셋 우상단 값.
    static let doodlePaperHighlight = Color(red: 0xFC / 255, green: 0xFC / 255, blue: 0xFC / 255)
    /// 메모지에서 접힌 모서리 쪽으로 지는 그늘. 같은 에셋 좌하단 값.
    static let doodlePaperShade = Color(red: 0xE4 / 255, green: 0xE4 / 255, blue: 0xE4 / 255)
    /// 버튼 눌림 배경. Figma `rgba(121,121,121,0.1)`
    static let doodlePressed = Color(red: 121 / 255, green: 121 / 255, blue: 121 / 255).opacity(0.1)
    /// 어두운 버튼 위 글자. Figma `#E8E8E8`
    static let doodleOnPrimary = Color(red: 0xE8 / 255, green: 0xE8 / 255, blue: 0xE8 / 255)

    /// 먹색 원형 버튼 위의 아이콘. Figma `iPhone 17 - 13` 의 `Frame 25` `#F2F2F2`
    ///
    /// `doodleOnPrimary`(#E8E8E8) 보다 한 톤 밝다.
    /// 저쪽은 글자, 이쪽은 획이 가는 심볼이라 같은 밝기로는 묻힌다.
    static let doodleOnDarkButton = Color(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF2 / 255)
}
