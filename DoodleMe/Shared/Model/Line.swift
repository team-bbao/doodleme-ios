//
//  Line.swift
//  DoodleMe
//

import CoreGraphics
import Foundation

/// 손그림의 한 획(stroke). 사용자가 화면에 손을 대고 뗄 때까지 찍힌 점들의 모음.
struct Line: Codable {
    var points: [CGPoint] = []
}

extension Line {
    /// 획이 주어진 점의 `radius` 안을 지나는지. 지우개 판정에 쓴다.
    func touches(_ point: CGPoint, within radius: CGFloat) -> Bool {
        let radiusSquared = radius * radius
        return points.contains { $0.distanceSquared(to: point) < radiusSquared }
    }
}
