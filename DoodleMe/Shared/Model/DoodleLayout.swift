//
//  DoodleLayout.swift
//  DoodleMe
//

import SwiftUI

/// 화면이 넓어졌을 때만 값을 키우는 자.
///
/// 이 앱의 치수는 Figma `iPhone 17`(402x874) 에 맞춰 하나하나 못박혀 있다.
/// 그대로 iPad 에 올리면 화면만 2.5 배가 되고 글자·프로필은 그대로라
/// 위쪽에 몰려 있고 아래가 텅 빈 모양이 된다.
/// 애플도 "13인치 화면에 아이폰 배치를 늘리는 것은 공간 낭비" 라고 말한다.
///
/// 그래서 **넓을 때만** 값을 키운다. 좁은 화면에서는 아무것도 달라지지 않는다.
enum DoodleLayout {

    /// 기준으로 삼는 아이폰 본문 폭. Figma 402 화면에서 좌우 20 씩을 뺀 값이다.
    static let baseContentWidth: CGFloat = 362

    /// 여기부터 "넓은 화면" 으로 본다.
    ///
    /// 가장 넓은 아이폰도 세로로 세우면 440 을 넘지 않는다.
    /// 600 에 두면 아이폰에서는 어떤 기종이든 늘 좁은 쪽으로 갈리므로,
    /// 지금까지의 화면이 한 픽셀도 달라지지 않는다.
    ///
    /// 폭을 직접 재는 이유가 있다. 애플은 기기 종류(`userInterfaceIdiom`)가 아니라
    /// 크기 클래스를 보라고 하는데, 그 이유가 "iPad 라도 Slide Over 에서는 좁아지기 때문" 이다.
    /// 실제로 주어진 폭을 재면 그 경우까지 저절로 맞고, 분할 화면 폭이 조금씩 달라져도
    /// 계단처럼 튀지 않고 이어진다. 크기 클래스는 `isWide(_:sizeClass:)` 로 함께 본다.
    static let wideThreshold: CGFloat = 600

    /// 넓은 화면인지.
    ///
    /// 폭이 먼저다. 크기 클래스만 보면 iPad 분할 화면에서 `regular` 인데도 좁은 경우를 놓친다.
    /// 크기 클래스는 폭이 애매할 때 한 번 더 걸러 주는 몫으로 함께 본다.
    static func isWide(_ width: CGFloat, sizeClass: UserInterfaceSizeClass? = nil) -> Bool {
        guard width >= wideThreshold else { return false }
        guard let sizeClass else { return true }
        return sizeClass == .regular
    }

    /// 아이폰 기준값을 넓은 화면에서 얼마나 키울지.
    ///
    /// 폭에 그대로 비례시키면 13인치에서 2.7 배가 되어 글자가 우스꽝스러워진다.
    /// 제곱근을 쓰면 넓어질수록 완만하게 커진다 — 11인치 1.48, 13인치 1.65.
    /// 그 이상은 더 키워 봐야 크기만 하고 읽기 좋아지지 않아 1.7 에서 멈춘다.
    static func scale(forWidth width: CGFloat, sizeClass: UserInterfaceSizeClass? = nil) -> CGFloat {
        guard isWide(width, sizeClass: sizeClass) else { return 1 }
        return min(1.7, (width / baseContentWidth).squareRoot())
    }

    /// 기준으로 삼는 아이폰 화면 높이. Figma `iPhone 17` 의 874.
    static let baseHeight: CGFloat = 874

    /// 세로로 놓이는 값(헤더 시작 높이, 제목 높이 …)을 얼마나 키울지.
    ///
    /// 폭만 보고 키우면 **가로로 눕혔을 때** 탈이 난다.
    /// 13인치를 눕히면 폭은 1376 이 되는데 높이는 1032 로 오히려 줄어든다.
    /// 폭만 따라 1.7 배로 키우면 헤더가 화면 아래로 밀려 내려가 카드가 설 자리가 없어진다.
    ///
    /// 그래서 가로값과 세로값 중 **작은 쪽**을 따른다. 세로가 모자라면 덜 키운다.
    static func verticalScale(forWidth width: CGFloat,
                              height: CGFloat,
                              sizeClass: UserInterfaceSizeClass? = nil) -> CGFloat {
        guard isWide(width, sizeClass: sizeClass), height > 0 else { return 1 }
        let byHeight = (height / baseHeight).squareRoot()
        return min(scale(forWidth: width, sizeClass: sizeClass), max(1, byHeight))
    }

    /// 글줄이 지나치게 길어지지 않도록 묶어 두는 폭.
    ///
    /// 애플이 `readableContentGuide` 로 제공하는 것과 같은 뜻이다.
    /// 한 줄이 너무 길면 눈이 다음 줄 첫머리를 찾지 못한다.
    static let readableWidth: CGFloat = 560
}
