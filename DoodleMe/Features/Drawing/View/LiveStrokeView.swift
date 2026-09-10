//
//  LiveStrokeView.swift
//  DoodleMe
//

import CoreGraphics
import PencilKit
import UIKit

/// 긋는 **동안**의 획을 대신 그려 보여주는 층.
///
/// PencilKit 은 획이 끝나야 그것을 `drawing.strokes` 에 넣어 준다.
/// 그 전에는 굵기에 손댈 방법이 없어, 속도로 매긴 굵기가 손을 뗀 뒤에야 나타났다.
///
/// 그래서 긋는 동안만 우리가 대신 그린다.
/// PencilKit 의 잉크는 실오라기만큼 얇게 두어 이 그림 밑에 숨고,
/// 손을 떼면 PencilKit 이 확정한 획이 자리를 넘겨받는다.
/// 속도를 굵기로 바꾸는 계산은 확정본과 같은 것(`PKStroke.widthScale`)을 쓴다.
final class LiveStrokeView: UIView {

    /// 한 점. 위치와 시각만 있으면 속도를 낼 수 있다.
    private struct Sample {
        let location: CGPoint
        let time: TimeInterval
    }

    private var samples: [Sample] = []
    /// 점마다 계산해 둔 굵기.
    private var widths: [CGFloat] = []
    /// 점마다의 속도(pt/초). 이웃과 평균 내려고 들고 있는다.
    private var speeds: [Double] = []

    /// 굵기의 기준값. `DrawingSession.Tool.penWidth` 를 그대로 받는다.
    var baseWidth: CGFloat = 3

    /// 속도를 평균 낼 때 지나온 쪽으로 몇 점까지 볼지.
    /// 확정본은 앞뒤를 함께 보지만, 긋는 도중에는 앞이 없다.
    private static let speedWindow = 3

    /// 시작을 가늘게 깎는 구간의 점 수.
    ///
    /// 확정본은 획 전체 점 수의 일부로 정하는데, 긋는 도중에는 전체를 알 수 없다.
    /// 그래서 시작 쪽만 짧게 깎아 둔다. 획의 첫머리와 끝머리는 손을 뗀 뒤 정확해진다.
    private static let startTaperCount = 8
    /// 끝점의 굵기 배율. 확정본과 같은 값.
    private static let tipScale: CGFloat = 0.45

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        // 그리기는 캔버스가 받는다. 이 층은 보여주기만 한다.
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - 입력

    func begin(at point: CGPoint, time: TimeInterval) {
        samples = [Sample(location: point, time: time)]
        speeds = [0]
        widths = [baseWidth * Self.tipScale]
        setNeedsDisplay()
    }

    func extend(to point: CGPoint, time: TimeInterval) {
        guard let previous = samples.last else {
            begin(at: point, time: time)
            return
        }

        // 같은 자리에서 떨리는 손끝은 그림을 바꾸지 않는다.
        let step = hypot(point.x - previous.location.x, point.y - previous.location.y)
        guard step > 0.1 else { return }

        samples.append(Sample(location: point, time: time))

        let elapsed = time - previous.time
        // 시각이 같게 들어오는 일이 있다. 그럴 때는 앞 속도를 그대로 잇는다.
        speeds.append(elapsed > 0 ? Double(step) / elapsed : (speeds.last ?? 0))

        let window = speeds.suffix(Self.speedWindow)
        let meanSpeed = window.reduce(0, +) / Double(window.count)

        let index = samples.count - 1
        widths.append(baseWidth * PKStroke.widthScale(forSpeed: meanSpeed) * Self.startTaper(at: index))
        setNeedsDisplay()
    }

    /// 손을 뗐다. PencilKit 이 확정한 획이 대신 보이므로 이 층은 비운다.
    func finish() {
        samples.removeAll()
        widths.removeAll()
        speeds.removeAll()
        setNeedsDisplay()
    }

    /// 획의 첫머리를 가늘게 만든다.
    private static func startTaper(at index: Int) -> CGFloat {
        guard index < startTaperCount else { return 1 }
        return tipScale + (1 - tipScale) * CGFloat(index) / CGFloat(startTaperCount)
    }

    // MARK: - 그리기

    override func draw(_ rect: CGRect) {
        guard samples.count > 1, let context = UIGraphicsGetCurrentContext() else { return }

        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // 굵기가 점마다 다르므로 한 번에 긋지 못한다.
        // 마디마다 제 굵기로 나눠 긋고, 둥근 끝으로 이어 붙여 매끄럽게 보이게 한다.
        for index in 1..<samples.count {
            context.setLineWidth(max(0.5, (widths[index - 1] + widths[index]) / 2))
            context.beginPath()
            context.move(to: samples[index - 1].location)
            context.addLine(to: samples[index].location)
            context.strokePath()
        }
    }
}
