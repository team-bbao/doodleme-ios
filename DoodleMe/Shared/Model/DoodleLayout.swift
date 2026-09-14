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

    /// 격자의 칸 사이 간격과 본문 좌우 여백이 넓은 화면에서 커지는 비율.
    ///
    /// 전체 배율(13인치 가로 1.7)을 그대로 쓰면 안 된다 —
    /// 간격과 여백이 커진 만큼 격자가 쓸 폭이 줄어 **열이 하나 사라진다.**
    /// 13인치 가로에서 6열이 5열이 되면 카드는 커지지만 한 화면에 보이는 장수가
    /// 세로(4열)보다 적어져, 눕히는 것이 손해가 된다.
    ///
    /// 경계를 재 보면 1.25 에서 무너진다. 여유를 두고 1.15 에서 묶는다.
    /// 이 값이면 카드 대비 간격 비율이 아이폰과 같아진다 —
    /// 아이폰 22/170 = 12.9%, 13인치 가로 25.3/198 = 12.8%.
    ///
    /// 넓은 화면은 어디서 재도 상한에 걸리므로(362 × 1.15² = 479 를 넘으면 상한),
    /// 어느 폭을 넣든 같은 값이 나온다.
    static func gridSpacingScale(forWidth width: CGFloat,
                                 sizeClass: UserInterfaceSizeClass? = nil) -> CGFloat {
        min(1.15, scale(forWidth: width, sizeClass: sizeClass))
    }

    /// 화면 제목(라지 타이틀) 기준 크기. Figma (20, 70) 의 34pt Bold.
    ///
    /// 갤러리·그리기·공유가 같은 규격을 쓴다. 값이 흩어져 있으면
    /// 한 화면만 고쳐져 탭을 오갈 때 제목이 튄다.
    static let titleFontSize: CGFloat = 34
    static let titleKerning: CGFloat = 0.4

    /// 제목이 이 화면에서 쓸 크기.
    ///
    /// **짧은 변**을 본다. 제목은 기기를 따르지 방향을 따르지 않는다 —
    /// 가로 폭으로 재면 눕힐 때마다 제목이 커졌다 작아진다.
    /// 11인치에서는 그 차이가 50.4 ↔ 57.8 로 15% 에 이른다(세로는 상한 1.7 에 닿지 않고
    /// 가로만 닿아서, 상한을 낮춰 봐야 세로는 그대로다).
    /// 짧은 변은 회전해도 같으므로 같은 기기에서 늘 같은 크기가 된다.
    ///
    /// 넣는 폭과 높이는 **안전영역을 뺀 본문 크기**로 통일한다.
    /// 한쪽은 화면 전체, 한쪽은 본문이면 같은 기기에서 다른 값이 나온다.
    ///
    /// 넓은 화면인지 가리는 `isWide` 는 지금처럼 가로 폭으로 둔다.
    /// 판정까지 짧은 변으로 바꾸면 눕힌 아이패드가 좁은 화면으로 갈린다.
    static func titleSize(forWidth width: CGFloat,
                          height: CGFloat,
                          sizeClass: UserInterfaceSizeClass? = nil) -> CGFloat {
        titleFontSize * scale(forWidth: min(width, height), sizeClass: sizeClass)
    }

    /// 가운데 모아 두는 조작부가 넓은 화면에서 늘어나지 않게 막는 폭.
    ///
    /// `readableWidth` 와 뜻이 다르다 — 그쪽은 글줄 길이고 이것은 손이 닿는 범위다.
    /// 아이폰 본문 폭(402 - 좌우 20 = 362)에 조금 여유를 둔 값이라,
    /// 아이폰에서는 어떤 조작부도 이 값에 닿지 않는다.
    static let controlMaxWidth: CGFloat = 440

    /// 조작부(닫기·공유·더 보기 같은 버튼)가 넓은 화면에서 커지는 비율.
    ///
    /// **콘텐츠 배율과 다르다.** 콘텐츠는 화면을 채우려고 커지지만 조작부는 손끝을 위해 커진다.
    /// 공유 화면의 X 가 이 구분 없이 그 화면의 콘텐츠 배율을 따랐다가 13인치에서 70pt 까지
    /// 부풀어, 같은 닫기 버튼인데 갤러리(47~55)와 40% 나 달랐다.
    ///
    /// **짧은 변**을 본다. 조작부는 기기를 따르지 방향을 따르지 않는다 —
    /// 한때 `verticalScale` 을 썼다가 13인치에서 버튼이 세로 55, 가로 48 로 오갔고,
    /// 세그먼트는 눕히면 38 까지 내려가 아이폰(35)과 구별되지 않았다.
    /// 누르는 것이 방향에 따라 크기를 바꾸면 손이 헷갈린다.
    ///
    /// 위로 묶는 까닭은 그리기 도구 막대와 같다 — 짧은 변 배율을 그대로 쓰면
    /// 13인치에서 버튼 한 변이 74 가 되어 조작부가 내용을 밀어낸다.
    /// 60pt(11.5mm)에서 멈추면 넉넉하면서 자리를 덜 먹고,
    /// **그리기 탭 도구 버튼과도 정확히 같은 크기**가 된다.
    ///
    /// 넣는 폭·높이는 **화면 전체**로 통일한다. 한 화면만 안전영역을 뺀 크기를 넣으면
    /// 같은 기기에서 버튼 크기가 어긋난다.
    static func chromeScale(forWidth width: CGFloat,
                            height: CGFloat,
                            sizeClass: UserInterfaceSizeClass? = nil) -> CGFloat {
        min(maxControlSide / DoodleMetrics.buttonSide,
            scale(forWidth: min(width, height), sizeClass: sizeClass))
    }

    /// 조작부 버튼 한 변이 커질 수 있는 끝. 그리기 도구 막대가 쓰는 값과 같다.
    static let maxControlSide: CGFloat = 60

    /// 글줄이 지나치게 길어지지 않도록 묶어 두는 폭.
    ///
    /// 애플이 `readableContentGuide` 로 제공하는 것과 같은 뜻이다.
    /// 한 줄이 너무 길면 눈이 다음 줄 첫머리를 찾지 못한다.
    static let readableWidth: CGFloat = 560
}
