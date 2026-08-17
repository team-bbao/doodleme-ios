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
}
