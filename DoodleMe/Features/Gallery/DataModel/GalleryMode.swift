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
    /// 내보낼 그림을 고른다. **어느 판으로 낼지가 함께 정해져 있다.**
    ///
    /// `choosingProfile` 과 나란히 두는 이유는 둘 다 "카드를 고르는 중" 이기 때문이다.
    /// 다만 고른 결과가 다르다. 저쪽은 한 장을 프로필로 앉히고, 이쪽은 카드로 내보낸다.
    /// 한 모드에 묶어 두면 카드를 눌렀을 때 무엇을 해야 할지 갈라낼 수 없다.
    ///
    /// 판을 **모드가 들고 있는** 이유는, 판 없이 고르는 중인 상태를 만들 수 없게 하려는 것이다.
    /// 고르기는 언제나 `iPhone 17 - 36` 에서 판을 고른 뒤에 열린다 —
    /// 그러지 않으면 다 고르고 나서야 한 장짜리 판이었다는 것을 알게 된다.
    case selecting(ExportTemplate)
}

extension GalleryMode {
    /// 카드가 "누르면 크게 보이는 것" 이 아니라 "고르는 대상" 인 상태.
    ///
    /// 어두운 막·툴바 숨김처럼 두 고르기 모드가 똑같이 따르는 처리를 한곳에서 판단한다.
    var isPickingCards: Bool {
        self != .browsing
    }

    /// 내보낼 그림을 고르는 중인지. 어느 판인지는 묻지 않는다.
    var isSelecting: Bool {
        if case .selecting = self { true } else { false }
    }

    /// 고르는 중이면 어느 판인지. 아니면 `nil`.
    var template: ExportTemplate? {
        if case .selecting(let template) = self { template } else { nil }
    }
}
