//
//  SpeechBubbleShape.swift
//  DoodleMe
//

import SwiftUI

/// 말풍선 모양. Figma `iPhone 17 - 28` 의 `Group 35 / 36 / 38`.
///
/// 내보낸 SVG 를 그대로 쓰지 않는다.
/// 그 그림들은 디자이너가 넣어 둔 **예시 글의 길이에 맞춰** 높이가 못박혀 있어
/// (129.669 / 129.669 / 187) 실제 한마디를 담으면 글이 넘치거나 아래가 텅 빈다.
/// 세 개를 뜯어 보니 모서리도 꼬리도 완전히 같고 **높이만** 다르다 — 그래서 직접 그린다.
///
/// 꼬리는 SVG 의 `Polygon 1` 을 좌표 그대로 옮긴 것이다.
/// 셋 다 같은 모양(폭 35.5 · 높이 31.5)이고 바뀌는 것은 좌우 어느 쪽에 붙느냐뿐이다.
struct SpeechBubbleTail: Shape {

    /// 꼬리가 왼쪽 아래에 붙는지. `false` 면 오른쪽으로 뒤집는다.
    let tailOnLeft: Bool

    /// 몸통 아래에 매달리는 꼬리.
    ///
    /// 좌표는 Figma SVG 의 절대값에서 **몸통 왼쪽 위**를 원점으로 옮긴 것이다.
    /// y 가 음수인 점들은 몸통 안쪽으로 파고든 부분이다.
    ///
    /// **몸통과 한 Path 로 합치지 않는다.**
    /// 합쳐 보니 겹친 7.6 만큼이 도로 뚫려 꼬리 위에 회색 띠가 생겼다 —
    /// 둥근 사각형과 이 꼬리의 감기는 방향이 반대라 `non-zero` 규칙에서 서로 지운 것이다.
    /// Figma SVG 도 `Rectangle 4` 와 `Polygon 1` 을 **따로** 두고 그림자를 각각 걸어 두었다.
    /// 꼬리를 먼저 깔고 몸통을 위에 얹으면 파고든 부분이 가려져 이음매가 보이지 않는다.
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: point(36.673, 20.499, in: rect))
        path.addCurve(to: point(45.407, 20.499, in: rect),
                      control1: point(38.580, 23.919, in: rect),
                      control2: point(43.500, 23.919, in: rect))
        path.addLine(to: point(56.944, -0.193, in: rect))
        path.addCurve(to: point(52.577, -7.628, in: rect),
                      control1: point(58.802, -3.525, in: rect),
                      control2: point(56.393, -7.628, in: rect))
        path.addLine(to: point(29.503, -7.628, in: rect))
        path.addCurve(to: point(25.136, -0.193, in: rect),
                      control1: point(25.688, -7.628, in: rect),
                      control2: point(23.278, -3.525, in: rect))
        path.closeSubpath()
        return path
    }

    /// 꼬리 좌표 하나. `x` 는 몸통 왼쪽에서, `y` 는 몸통 **아랫변**에서 잰 값이다.
    ///
    /// 오른쪽 꼬리는 몸통 한가운데를 축으로 좌우를 뒤집는다.
    /// Figma 도 같은 그림에 `-scale-y-100 rotate-180`(둘을 합치면 좌우 반전)을 걸어 두었다.
    private func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + (tailOnLeft ? x : rect.width - x),
                y: rect.maxY + y)
    }

    /// Figma `Rectangle 4` 의 `rx`.
    static let cornerRadius: CGFloat = 30

    /// 꼬리 끝이 몸통 아랫변보다 얼마나 더 내려가는지. 자리를 잡을 때 이만큼 더 잡아 둔다.
    static let tailDrop: CGFloat = 23.919
}
