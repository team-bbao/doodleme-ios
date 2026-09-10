//
//  GalleryMode.swift
//  DoodleMe
//

/// 갤러리 그리드가 지금 무슨 일을 하고 있는지.
///
/// 예전에는 "편집 중"을 뜻하는 Bool 과 "프로필 고르는 중"을 뜻하는 Bool 이 따로 있어서
/// 둘 다 켜진 상태 같은 게 표현될 수 있었다. 하나의 모드로 묶어 그런 조합을 없앤다.
enum GalleryMode: Equatable {
    /// 평소. 카드를 탭하면 크게 본다.
    case browsing
    /// 한 장을 골라 프로필로 설정한다.
    case choosingProfile
    /// 여러 장을 골라 한 번에 지운다.
    ///
    /// `choosingProfile` 과 나란히 두는 이유는 둘 다 "카드를 고르는 중" 이기 때문이다.
    /// 다만 고른 결과가 다르다. 저쪽은 한 장을 프로필로 앉히고, 이쪽은 여러 장을 지운다.
    /// 한 모드에 묶어 두면 카드를 눌렀을 때 무엇을 해야 할지 갈라낼 수 없다.
    case selecting
}

extension GalleryMode {
    /// 카드가 "누르면 크게 보이는 것" 이 아니라 "고르는 대상" 인 상태.
    ///
    /// 어두운 막·툴바 숨김처럼 두 고르기 모드가 똑같이 따르는 처리를 한곳에서 판단한다.
    var isPickingCards: Bool {
        self != .browsing
    }
}
