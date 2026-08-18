//
//  DoodleStrokeAnimation.swift
//  DoodleMe
//

import PencilKit
import SwiftUI

/// 그림을 **그려진 순서대로** 다시 그려 보여준다. 한 바퀴 끝나면 잠깐 멈췄다가 처음부터 반복한다.
///
/// SwiftUI 의 암묵적 애니메이션(`trim` + `withAnimation`)으로 만들면
/// 모든 획이 동시에 그려지거나, 획마다 delay 를 주면 반복할 때 서로 어긋난다.
/// 그래서 `TimelineView` 로 매 프레임 경과 시간을 직접 받아 어디까지 그릴지 계산한다.
struct DoodleStrokeAnimation: View {

    /// 획마다 등간격으로 뽑아둔 점들. 매 프레임 다시 계산하지 않도록 init 에서 한 번만 만든다.
    private let strokes: [[CGPoint]]
    private let totalPointCount: Int
    /// 획들이 실제로 차지하는 영역. 캔버스 전체가 아니라 이 영역을 화면에 맞춘다.
    private let contentBounds: CGRect
    private let lineWidth: CGFloat
    /// 한 바퀴 그리는 데 걸리는 시간.
    private let drawDuration: TimeInterval
    /// 다 그린 뒤 그대로 머무는 시간.
    private let holdDuration: TimeInterval

    @State private var startDate = Date()

    init(
        drawing: PKDrawing,
        lineWidth: CGFloat = 2,
        drawDuration: TimeInterval = 2.6,
        holdDuration: TimeInterval = 0.7
    ) {
        self.strokes = drawing.strokes.map { stroke in
            stroke.path
                .interpolatedPoints(by: .distance(2))
                .map { $0.location.applying(stroke.transform) }
        }
        self.totalPointCount = strokes.reduce(0) { $0 + $1.count }
        self.contentBounds = Self.bounds(of: strokes)
        self.lineWidth = lineWidth
        self.drawDuration = drawDuration
        self.holdDuration = holdDuration
    }

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { graphics, size in
                draw(in: graphics, size: size, progress: progress(at: context.date))
            }
        }
        .accessibilityHidden(true)
    }

    /// 0 → 1 로 갔다가 잠시 머문 뒤 다시 0 으로 돌아온다.
    private func progress(at date: Date) -> Double {
        guard totalPointCount > 0 else { return 0 }
        let cycle = drawDuration + holdDuration
        let elapsed = date.timeIntervalSince(startDate).truncatingRemainder(dividingBy: cycle)
        return min(1, elapsed / drawDuration)
    }

    /// 획들을 감싸는 최소 사각형.
    private static func bounds(of strokes: [[CGPoint]]) -> CGRect {
        var minX = CGFloat.infinity, minY = CGFloat.infinity
        var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity

        for stroke in strokes {
            for point in stroke {
                minX = min(minX, point.x); maxX = max(maxX, point.x)
                minY = min(minY, point.y); maxY = max(maxY, point.y)
            }
        }
        guard minX <= maxX, minY <= maxY else { return .zero }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func draw(in graphics: GraphicsContext, size: CGSize, progress: Double) {
        guard totalPointCount > 0 else { return }

        // 캔버스 전체가 아니라 그림이 실제로 차지하는 영역을 화면에 맞춘다.
        // 캔버스 기준으로 맞추면 구석에 작게 그린 그림이 그대로 작고 치우쳐 보인다.
        // 점 하나짜리 그림도 있을 수 있으니 폭·높이가 0 이면 배율을 1 로 둔다.
        let scale = min(
            contentBounds.width > 0 ? size.width / contentBounds.width : 1,
            contentBounds.height > 0 ? size.height / contentBounds.height : 1
        )
        let drawnSize = CGSize(width: contentBounds.width * scale,
                               height: contentBounds.height * scale)

        var graphics = graphics
        graphics.translateBy(x: (size.width - drawnSize.width) / 2,
                             y: (size.height - drawnSize.height) / 2)
        graphics.scaleBy(x: scale, y: scale)
        graphics.translateBy(x: -contentBounds.minX, y: -contentBounds.minY)

        let style = StrokeStyle(lineWidth: lineWidth / scale, lineCap: .round, lineJoin: .round)
        var remaining = Int(progress * Double(totalPointCount))

        for stroke in strokes {
            guard remaining > 1 else { break }

            let take = min(stroke.count, remaining)
            if take > 1 {
                var path = Path()
                path.addLines(Array(stroke.prefix(take)))
                graphics.stroke(path, with: .color(.black), style: style)
            }
            remaining -= stroke.count
        }
    }
}
