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
    /// 내보낼 그림을 고르는 동안 뒤를 덮는 농도. Figma `iPhone 17 - 38` 의 `Rectangle 2`.
    ///
    /// 프로필 고르기(`doodleChoosingScrim`, 16%)보다 한 단 짙다.
    /// 구운 화면에서 재면 바탕 `#F2F2F7`(242)이 193 으로 내려앉아 검정 20% 다.
    static let doodleSelectingScrim = Color.black.opacity(0.20)

    /// 고른 카드를 덮는 색. Figma `iPhone 17 - 38` 의 `Rectangle 9` — `#808080` 50%.
    ///
    /// 검정을 옅게 까는 것과 다르다. 흰 종이(250)가 189 로 내려앉는데,
    /// 검정 24% 로는 190 이 나와도 어두운 획까지 함께 묻힌다.
    /// 회색 50% 는 **밝은 데는 낮추고 어두운 데는 올려** 그림이 남는다.
    static let doodleSelectedTint = Color(white: 0x80 / 255).opacity(0.5)

    /// 세그먼트에서 선택된 칸을 덮는 캡슐. Figma `iPhone 17 - 12` `#F1F1F1`
    static let doodleSegmentChip = Color(red: 0xF1 / 255, green: 0xF1 / 255, blue: 0xF1 / 255)
    /// 선택된 세그먼트 라벨. Figma `#212121`
    static let doodleSegmentLabel = Color(red: 0x21 / 255, green: 0x21 / 255, blue: 0x21 / 255)
    /// 확인창에서 물러나는 쪽 버튼 바탕.
    /// Figma 가 시스템 토큰 `fills/secondary` 를 그대로 쓰므로 우리도 같은 것을 쓴다.
    static let doodleControlFill = Color(uiColor: .secondarySystemFill)
    /// 개수 알약 유리에 얹는 틴트. Figma `_Search - Bottom` 의 `#444444` 60% 자리다.
    ///
    /// 맨 유리는 밝은 바탕에서 흰빛을 많이 얹어 Figma(213)보다 밝게(236) 뜬다.
    /// 이 값은 **구운 화면을 재 맞춘 것**이라, 유리 구현이 바뀌면 다시 재야 한다.
    static let doodlePillTint = Color.black.opacity(0.10)

    /// 개수 알약 테두리. Figma `_Search - Bottom` 의 `#E8E8E8`.
    static let doodlePillBorder = Color(red: 0xE8 / 255, green: 0xE8 / 255, blue: 0xE8 / 255)

    /// 확인창 테두리. Figma `iPhone 17 - 16` `#DBDBDB`
    static let doodlePopupBorder = Color(red: 0xDB / 255, green: 0xDB / 255, blue: 0xDB / 255)
    /// 카드 툴바에서 눌린 버튼 바탕. Figma `iPhone 17 - 14` `#E4E4E5`
    static let doodleCardToolbarPressed = Color(red: 0xE4 / 255, green: 0xE4 / 255, blue: 0xE5 / 255)
    /// 화면 제목. Figma 라지 타이틀 `#1A1A1A`
    static let doodleTitle = Color(red: 0x1A / 255, green: 0x1A / 255, blue: 0x1A / 255)

    /// 그림이 하나도 없을 때 뜨는 안내 문구. Figma `iPhone 17 - 12` 의 `85:349` `#9D9D9D`
    ///
    /// 예전에는 `colorGray`(#424242)에 `opacity(0.4)` 를 겹쳐 썼는데,
    /// 배경(#F2F2F7)과 섞이면서 실제로는 #ACACAF 로 흐려져 디자인보다 밝았다.
    /// 단색으로 못박아 배경이 달라져도 같은 색이 나오게 한다.
    static let doodleEmptyHint = Color(red: 0x9D / 255, green: 0x9D / 255, blue: 0x9D / 255)

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

    /// 고른 것을 확정하는 파란 단추. Figma `_Button - Symbol` 의 `accents/blue` `#0088FF`.
    ///
    /// 이 화면에서 **색이 찬 것은 이 하나뿐**이다.
    /// 나머지는 흰 유리나 먹색이라, 파랑은 「여기를 눌러 다음으로 간다」는 뜻으로만 쓴다.
    static let doodleAccent = Color(red: 0x00 / 255, green: 0x88 / 255, blue: 0xFF / 255)

    /// 먹색 원형 버튼 위의 아이콘. Figma `iPhone 17 - 13` 의 `Frame 25` `#F2F2F2`
    ///
    /// `doodleOnPrimary`(#E8E8E8) 보다 한 톤 밝다.
    /// 저쪽은 글자, 이쪽은 획이 가는 심볼이라 같은 밝기로는 묻힌다.
    static let doodleOnDarkButton = Color(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF2 / 255)
}
