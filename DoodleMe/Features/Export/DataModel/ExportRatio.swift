//
//  ExportRatio.swift
//  DoodleMe
//

import SwiftUI

/// 내보낼 카드의 판형.
///
/// 인스타그램은 올리는 자리마다 받는 비율이 다르다.
/// 한 벌만 구워 두면 나머지 자리에서는 인스타그램이 알아서 잘라 버리는데,
/// 실제로 9:16 을 피드에 올려 보니 **위아래 각 21.2%** 가 날아가 제목과 꼬리말이 사라졌다.
/// 그래서 올릴 자리를 먼저 고르고 그 규격으로 굽는다.
///
/// **Figma 세로(871)는 셋 다 그대로다.**
/// 원본 프레임이 402x871(1 : 2.167)이라 세 비율 모두 그보다 가로로 넓다 —
/// 좌우만 넓혀 종이를 이으면 안쪽 구성은 좌표 하나 건드리지 않아도 된다.
/// 9:16 을 만들 때 쓴 방법 그대로다(`ExportCardLayout` 주석).
enum ExportRatio: String, CaseIterable, Identifiable, Sendable {

    /// 스토리·릴스. 메타 「Sharing to Stories」 가 권하는 규격이다 —
    /// 배경 이미지를 최소 720x1280, 9:16 또는 9:18 로 두라고 한다.
    case story
    /// 피드 게시물. 인스타그램이 받는 가장 긴 세로다.
    case post
    /// 정사각형. 예전 게시물 규격이자 프로필에서 쓰던 판이다.
    case profile

    var id: Self { self }

    /// 세그먼트에 적히는 이름.
    var label: String {
        switch self {
        case .story: "스토리"
        case .post: "게시물"
        case .profile: "프로필"
        }
    }

    /// 폭 ÷ 높이.
    var value: CGFloat {
        switch self {
        case .story: 9.0 / 16
        case .post: 4.0 / 5
        case .profile: 1
        }
    }

    /// 파일 이름에 붙는 꼬리. 사진 앱에서 어느 판인지 바로 읽힌다.
    var fileTag: String {
        switch self {
        case .story: "9x16"
        case .post: "4x5"
        case .profile: "1x1"
        }
    }

    /// 낭독기가 읽을 말. 「스토리」 만으로는 무엇을 고르는지 알 수 없다.
    var accessibilityLabel: String {
        switch self {
        case .story: "스토리, 9 대 16"
        case .post: "게시물, 4 대 5"
        case .profile: "프로필, 정사각형"
        }
    }
}

extension EnvironmentValues {
    /// 지금 그리는 카드가 어느 판인지.
    ///
    /// 카드 안쪽(`ExportCard`·`ExportDrawingsCard`)이 저마다 폭을 알아야 하는데
    /// 그걸 모든 카드의 생성자로 받아 넘기면 세 카드가 전부 같은 값을 손에서 손으로 옮기게 된다.
    /// 판형은 화면 전체에 걸린 한 가지 설정이라 환경으로 내린다.
    ///
    /// **굽는 쪽에서는 환경이 저절로 따라가지 않는다.**
    /// `ImageRenderer` 는 화면에 붙지 않은 뷰를 그리므로
    /// `ExportRenderer` 가 카드에 직접 걸어 준다.
    @Entry var exportRatio: ExportRatio = .story
}
