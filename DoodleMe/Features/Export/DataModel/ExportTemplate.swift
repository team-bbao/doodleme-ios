//
//  ExportTemplate.swift
//  DoodleMe
//

/// 인스타그램에 올릴 카드의 판. Figma `iPhone 17 - 36` 이 고르게 하는 둘이다.
///
/// 고르는 것은 **결과물의 모양**이지 장수가 아니다.
/// 다만 판이 정해지면 몇 장을 담을 수 있는지도 함께 정해진다 —
/// 한 장짜리 카드에 두 장을 담을 수는 없다.
/// 그래서 이 값이 갤러리에서 카드를 누를 때의 동작(`GalleryMode.selecting`)까지 정한다.
enum ExportTemplate: String, CaseIterable, Identifiable, Sendable {

    /// 그림 하나. `ExportSinglePostCard` — 그림 한 장과 거기 딸린 한마디.
    case single
    /// 그림 여러개. `ExportDrawingsCard` — 종이 한 장에 여섯 칸씩.
    case multiple

    var id: String { rawValue }

    /// Figma `iPhone 17 - 36` 의 단추 글자.
    var title: String {
        switch self {
        case .single: "그림 하나"
        case .multiple: "그림 여러개"
        }
    }

    /// 한 번에 몇 장까지 고를 수 있는지.
    ///
    /// **카드 한 장에 담기는 만큼이다.** 그림 여러개 판은 여섯 칸짜리라
    /// 일곱 번째부터는 둘째 장으로 넘어가는데, 한 번 내보낼 때 카드가 여러 장 나오면
    /// 인스타그램에 올릴 때마다 무엇을 올릴지 다시 골라야 한다.
    /// 한 번에 한 장이 나오게 막고, 더 내려면 한 번 더 내보내면 된다.
    ///
    /// 가진 그림이 여섯 장보다 적으면 있는 만큼만 고르게 되므로 따로 막을 것이 없다.
    var selectionLimit: Int {
        switch self {
        case .single: 1
        case .multiple: ExportDrawingsCard.perPage
        }
    }
}
