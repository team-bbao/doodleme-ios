//
//  GallerySection.swift
//  DoodleMe
//

import Foundation

/// 갤러리 세그먼트가 지금 어느 쪽을 보고 있는지.
///
/// 예전에는 `segmentedBar == 1` 같은 숫자 비교가 화면마다 흩어져 있었다.
/// 그리기를 마치거나 그림을 받았을 때 탭을 옮겨 주면서 숫자를 아는 곳이 더 늘어나,
/// 어느 쪽이 0 인지 한곳에서만 알도록 이름을 붙였다.
///
/// 세그먼트에 그려지는 **순서**는 아래 `case` 를 적은 차례를 따른다.
/// `rawValue` 는 그 순서와 별개로, 저장소와 다른 화면이 주고받는 값이다.
///
/// 둘을 갈라 둔 이유가 있다.
/// 디자인이 칸의 좌우를 바꿔도 이미 저장된 값의 뜻은 그대로여야 한다.
/// 함께 바꾸면 앱을 새로 켠 사람에게 엉뚱한 칸이 펴진다.
enum GallerySection: Int, CaseIterable {
    /// 내가 그린 그림. Figma `Frame 38`(85:536) 은 이쪽을 왼쪽에 둔다.
    case drawnByMe = 1
    /// 남이 그려서 보내준 그림.
    case receivedFromOthers = 0

    /// 세그먼트에 표시할 이름.
    var title: String {
        switch self {
        case .receivedFromOthers: "너가 그린"
        case .drawnByMe: "내가 그린"
        }
    }
}

extension GallerySection {
    /// 화면 사이에 걸쳐 있는 값이라 저장소를 통해 주고받는다.
    ///
    /// 그리기 화면과 공유 화면은 갤러리를 직접 들고 있지 않다.
    /// 저장을 마친 쪽이 여기에 적어 두면, 갤러리가 그걸 보고 해당 탭을 연다.
    static let storageKey = "gallerySection"
}
