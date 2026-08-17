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
    /// 여러 장을 골라 삭제한다.
    case deleting
}
