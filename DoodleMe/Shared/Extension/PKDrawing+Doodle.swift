//
//  PKDrawing+Doodle.swift
//  DoodleMe
//

import PencilKit
import UIKit

// 모델 계층(`Post`)에서도 쓰이므로 메인 액터에 묶지 않는다.
nonisolated extension PKDrawing {
    /// 저장된 바이너리에서 복원한다. 깨진 데이터면 빈 그림.
    init(doodleData: Data) {
        self = (try? PKDrawing(data: doodleData)) ?? PKDrawing()
    }

    /// 획을 등간격(2pt) 점열로 푼다. 되살아나는 애니메이션이 이 형태를 받는다.
    ///
    /// 원본 점은 손이 빠른 구간에서 듬성듬성해서, 그대로 쓰면 그리는 속도가 들쭉날쭉하다.
    /// 간격을 고르게 맞춰야 일정한 속도로 되살아난다.
    var pointStrokes: [[CGPoint]] {
        strokes.map { stroke in
            stroke.path
                .interpolatedPoints(by: .distance(2))
                .map { $0.location.applying(stroke.transform) }
        }
    }

    /// 기준 캔버스(`DoodleMetrics.canvasSize`) 전체를 이미지로 굽는다.
    ///
    /// 그림이 실제로 차지하는 영역(`bounds`)이 아니라 캔버스 전체를 렌더링해야
    /// 그리드·상세·프로필에서 위치와 비율이 원본과 같게 유지된다.
    func canvasImage(scale: CGFloat = 3) -> UIImage {
        let canvas = CGRect(origin: .zero, size: DoodleMetrics.canvasSize)
        let rendered = image(from: canvas, scale: scale)

        // 메모지 모서리 바깥으로 나간 획을 잘라낸다.
        //
        // 그리는 화면에서는 캔버스를 둥글게 잘라 두었지만, 그건 보이는 것만 자를 뿐
        // 저장되는 좌표까지 막지는 못한다. 여기서 자르지 않으면 그리드·상세·프로필에서
        // 종이 밖으로 획이 삐져나온다. 이미 저장된 그림도 여기서 함께 정리된다.
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: canvas.size, format: format).image { _ in
            UIBezierPath(roundedRect: canvas, cornerRadius: DoodleMetrics.canvasCornerRadius).addClip()
            rendered.draw(in: canvas)
        }
    }
}

extension Post {
    var drawing: PKDrawing {
        PKDrawing(doodleData: drawingData)
    }

    var senderProfileDrawing: PKDrawing? {
        senderProfileDrawingData.map { PKDrawing(doodleData: $0) }
    }
}
