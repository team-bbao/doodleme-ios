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

    /// 기준 캔버스(`DoodleMetrics.canvasSize`) 전체를 이미지로 굽는다.
    ///
    /// 그림이 실제로 차지하는 영역(`bounds`)이 아니라 캔버스 전체를 렌더링해야
    /// 그리드·상세·프로필에서 위치와 비율이 원본과 같게 유지된다.
    func canvasImage(scale: CGFloat = 3) -> UIImage {
        image(from: CGRect(origin: .zero, size: DoodleMetrics.canvasSize), scale: scale)
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
