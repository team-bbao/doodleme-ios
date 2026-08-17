//
//  CGPoint+Distance.swift
//  DoodleMe
//

import CoreGraphics
import Foundation

extension CGPoint {
    /// 두 점 사이의 유클리드 거리.
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }

    /// 거리의 제곱. 반지름과 크기만 견주면 될 때는 `sqrt`를 건너뛸 수 있어 더 빠르다.
    func distanceSquared(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return dx * dx + dy * dy
    }
}
