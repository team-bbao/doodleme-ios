//
//  GallerySortOrder.swift
//  DoodleMe
//

import Foundation

/// 갤러리 카드를 어느 순서로 늘어놓을지. Figma `iPhone 17 - 13` 의 `Frame 41`(142:706).
///
/// 두 섹션(「너가 그린」·「내가 그린」)이 이 값을 함께 쓴다.
/// 정렬은 보는 방법이지 그림의 성질이 아니라서, 섹션을 옮겨 다녀도 고른 순서가 따라다니는 편이 자연스럽다.
///
/// `rawValue` 는 메뉴에 그려지는 순서다.
enum GallerySortOrder: Int, CaseIterable {
    /// 최근에 들어온 것이 위로. 처음 열었을 때의 순서다.
    case newestFirst = 0
    /// 오래된 것이 위로.
    case oldestFirst = 1

    /// 메뉴에 표시할 이름.
    var title: String {
        switch self {
        case .newestFirst: "최근 추가된 순으로 정렬"
        case .oldestFirst: "오래된 순으로 정렬"
        }
    }
}

extension GallerySortOrder {
    /// 고른 순서는 앱을 닫았다 열어도 남는다. 정렬은 한 번 정하면 계속 쓰는 취향에 가깝다.
    /// `GallerySection` 과 같은 이유로 저장소를 통해 오간다.
    static let storageKey = "gallerySortOrder"
}
