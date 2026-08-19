//
//  PKDrawing+Velocity.swift
//  DoodleMe
//

import CoreGraphics
import Foundation
import PencilKit

// 손가락으로 그릴 때 굵기가 변하게 한다.
//
// PencilKit 은 터치의 힘(force)으로 굵기를 정한다.
// 애플펜슬은 힘을 주지만 손가락은 주지 않으므로, 손으로 그리면 굵기가 일정하다.
//
// 대신 긋는 속도를 쓴다. 천천히 그으면 두껍게, 빠르게 그으면 얇게.
// 실제로 펜을 눌러 쓸 때 손이 느려지는 것과 방향이 같아서 필압처럼 읽힌다.
nonisolated extension PKDrawing {

    /// 속도로 굵기를 다시 매긴 그림.
    ///
    /// 같은 그림에 두 번 적용해도 결과가 같다.
    /// 점의 위치와 시각만 보고 계산하므로, 이미 굵기가 매겨져 있어도 같은 값이 나온다.
    func withVelocityBasedWidth(baseWidth: CGFloat) -> PKDrawing {
        PKDrawing(strokes: strokes.map { $0.withVelocityBasedWidth(baseWidth: baseWidth) })
    }
}

nonisolated extension PKStroke {

    fileprivate func withVelocityBasedWidth(baseWidth: CGFloat) -> PKStroke {
        let points = Array(path)
        guard points.count > 1 else { return self }

        let speeds = Self.smoothedSpeeds(of: points)
        let shaped = points.enumerated().map { index, point in
            let width = baseWidth
                * Self.widthScale(forSpeed: speeds[index])
                * Self.endTaper(at: index, count: points.count)

            return PKStrokePoint(
                location: point.location,
                timeOffset: point.timeOffset,
                size: CGSize(width: width, height: width),
                opacity: point.opacity,
                force: point.force,
                azimuth: point.azimuth,
                altitude: point.altitude
            )
        }

        var stroke = self
        stroke.path = PKStrokePath(controlPoints: shaped, creationDate: path.creationDate)
        return stroke
    }

    /// 점마다의 속도(pt/초). 이웃과 평균 내어 들쭉날쭉한 값을 눌러 준다.
    private static func smoothedSpeeds(of points: [PKStrokePoint]) -> [Double] {
        var raw = [Double](repeating: 0, count: points.count)
        for index in 1..<points.count {
            let previous = points[index - 1], current = points[index]
            let distance = hypot(current.location.x - previous.location.x,
                                 current.location.y - previous.location.y)
            let elapsed = current.timeOffset - previous.timeOffset
            // 같은 시각에 찍힌 점이 있을 수 있다. 그런 구간은 앞 값을 그대로 쓴다.
            raw[index] = elapsed > 0 ? Double(distance) / elapsed : raw[index - 1]
        }
        raw[0] = raw.count > 1 ? raw[1] : 0

        // 앞뒤 두 점씩 평균. 창을 더 넓히면 굵기가 뭉개져 밋밋해진다.
        let window = 2
        return raw.indices.map { index in
            let lower = max(0, index - window)
            let upper = min(raw.count - 1, index + window)
            return raw[lower...upper].reduce(0, +) / Double(upper - lower + 1)
        }
    }

    /// 속도를 굵기 배율로 바꾼다. 느리면 두껍고 빠르면 얇다.
    private static func widthScale(forSpeed speed: Double) -> CGFloat {
        // 손가락 낙서는 대체로 0 ~ 1800 pt/초 사이에서 움직인다.
        let normalized = min(1, max(0, speed / 1800))
        // 느릴 때 1.6배, 빠를 때 0.85배.
        // 더 벌리면 빠르게 그은 획이 실처럼 얇아져 잘 안 보인다.
        return 1.6 - 0.75 * CGFloat(normalized)
    }

    /// 획의 시작과 끝을 가늘게 만든다.
    ///
    /// 속도만 쓰면 손이 멈추는 양 끝이 가장 두꺼워져 몽둥이처럼 보인다.
    /// 실제로 펜을 대고 떼는 자리는 오히려 가늘다.
    private static func endTaper(at index: Int, count: Int) -> CGFloat {
        let taper = max(1, count / 8)
        let fromStart = index
        let fromEnd = count - 1 - index
        let edge = min(fromStart, fromEnd)
        guard edge < taper else { return 1 }
        // 끝점에서 0.45 배, 안쪽으로 갈수록 1 배에 가까워진다.
        return 0.45 + 0.55 * CGFloat(edge) / CGFloat(taper)
    }
}
