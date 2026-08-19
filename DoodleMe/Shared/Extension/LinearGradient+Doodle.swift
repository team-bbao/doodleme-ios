//
//  LinearGradient+Doodle.swift
//  DoodleMe
//

import SwiftUI

extension LinearGradient {
    /// 메모지 본체. 접힌 모서리 쪽으로 갈수록 그늘이 진다.
    ///
    /// `memoBack` 에셋의 그라디언트를 대각선으로 재서 옮겼다.
    /// 본체의 3분의 2 는 평평하고, 모서리에 가까워지는 마지막 구간에서만 떨어진다.
    ///
    /// 그리드 카드와 확대 카드가 함께 쓴다.
    /// 한쪽은 에셋 위에 덮고 다른 쪽은 도형에 채우지만,
    /// 같은 값을 보고 있으니 카드를 눌러 확대해도 종이 색이 튀지 않는다.
    /// `Color` 상수들이 메인 액터에 묶여 있어 격리 밖에서는 읽을 수 없다.
    /// 쓰는 쪽이 모두 View 라 메인 액터에 두면 그만이고,
    /// 만드는 값이 가벼워 저장해 두지 않고 매번 지어도 부담이 없다.
    @MainActor
    static var doodlePaperFace: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .doodlePaperHighlight, location: 0),
                .init(color: .doodlePaper, location: 0.25),
                .init(color: .doodlePaper, location: 0.65),
                .init(color: .doodlePaperShade, location: 1)
            ],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
    }
}
