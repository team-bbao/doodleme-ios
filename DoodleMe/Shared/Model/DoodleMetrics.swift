//
//  DoodleMetrics.swift
//  DoodleMe
//

import CoreGraphics

nonisolated enum DoodleMetrics {
    /// 그림을 그리고 보여주는 기준 캔버스 크기.
    /// 저장된 좌표는 모두 이 크기를 기준으로 하므로, 축소해 보여줄 때는 이 값으로 나눠 배율을 구한다.
    static let canvasSize = CGSize(width: 350, height: 390)

    /// 메모지와 캔버스가 공유하는 모서리 반경.
    /// 두 값이 어긋나면 모서리 바깥에도 획이 그려진다.
    static let canvasCornerRadius: CGFloat = 50
}
