//
//  DrawingCanvas.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/10/26.
//

import PencilKit
import SwiftUI
import UIKit

/// PencilKit 캔버스. 손가락과 Apple Pencil 양쪽으로 그릴 수 있다.
///
/// 크기를 이 뷰 안에서 못박는다. `UIViewRepresentable` 은 프레임을 주지 않으면
/// 제안된 크기를 그대로 채우기 때문에, 호출하는 쪽에서 `.frame` 을 빠뜨리면
/// 캔버스가 메모지를 넘어 화면 전체로 퍼지고 저장되는 좌표까지 어긋난다.
struct DrawingCanvas: View {

    let session: DrawingSession

    var body: some View {
        CanvasRepresentable(session: session)
            .frame(
                width: DoodleMetrics.canvasSize.width,
                height: DoodleMetrics.canvasSize.height
            )
            // 메모지는 모서리가 둥근데 캔버스는 네모라, 자르지 않으면
            // 종이 바깥의 네 모서리에도 획이 그려진다.
            .clipShape(RoundedRectangle(cornerRadius: DoodleMetrics.canvasCornerRadius))
    }
}

/// 그림도 되돌리기도 `PKCanvasView` 가 가진다. 우리는 읽기만 한다.
///
/// 예전에는 손가락에 필압 느낌을 주려고 획을 그을 때마다 굵기를 다시 매겨
/// 그림 전체를 캔버스에 되돌려 넣었다. 그 대입이 PencilKit 의 상태와 어긋났다.
/// 특히 **획이 줄어든 그림은 받아들여지지 않았다.** 되돌리기로 지운 획이
/// 화면에서만 사라졌다가, 다음 획을 긋는 순간 PencilKit 이 자기가 들고 있던
/// 예전 상태를 되살려 새 획과 함께 다시 나타났다.
///
/// 그리는 주체가 PencilKit 이면 그림의 주인도 PencilKit 이어야 한다.
private struct CanvasRepresentable: UIViewRepresentable {

    let session: DrawingSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeUIView(context: Context) -> DoodleCanvasView {
        let canvas = DoodleCanvasView()
        canvas.delegate = context.coordinator
        // 기본값은 Apple Pencil 전용이라, 손가락으로도 그릴 수 있게 열어준다.
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        // 캔버스가 스크롤·확대되면 저장 좌표와 화면 좌표가 어긋난다.
        canvas.isScrollEnabled = false
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.tool = session.tool.pkTool
        canvas.drawing = session.drawing
        return canvas
    }

    func updateUIView(_ canvas: DoodleCanvasView, context: Context) {
        canvas.tool = session.tool.pkTool

        // 버튼이 눌린 횟수만 세어 두고, 우리가 아는 횟수와 달라졌을 때 한 번씩 흘려보낸다.
        // 세션은 캔버스를 직접 부를 길이 없고, 캔버스는 화면이 갱신될 때마다 여기를 지난다.
        if context.coordinator.undoRequest != session.undoRequest {
            context.coordinator.undoRequest = session.undoRequest
            canvas.undoManager?.undo()
            context.coordinator.refreshHistoryState(of: canvas)
        }

        if context.coordinator.redoRequest != session.redoRequest {
            context.coordinator.redoRequest = session.redoRequest
            canvas.undoManager?.redo()
            context.coordinator.refreshHistoryState(of: canvas)
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let session: DrawingSession

        /// 이 캔버스가 이미 처리한 되돌리기·다시하기 횟수.
        var undoRequest = 0
        var redoRequest = 0

        init(session: DrawingSession) {
            self.session = session
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // 저장할 때 쓸 사본을 한 벌 받아 둔다. 이 값으로 캔버스를 되돌리지는 않는다.
            session.canvasDidChange(drawing: canvasView.drawing)
            refreshHistoryState(of: canvasView)
        }

        /// 버튼의 활성 여부를 캔버스의 되돌리기 사정에 맞춘다.
        ///
        /// PencilKit 이 방금 그은 획을 기록에 올리는 시점이 이 호출보다 늦을 수 있다.
        /// 그 자리에서 읽으면 한 박자 뒤처진 값이 나오므로 한 바퀴 뒤에 읽는다.
        func refreshHistoryState(of canvasView: PKCanvasView) {
            let session = session
            DispatchQueue.main.async { [weak canvasView] in
                guard let manager = canvasView?.undoManager else { return }
                session.updateHistoryState(canUndo: manager.canUndo, canRedo: manager.canRedo)
            }
        }
    }
}

/// 메모지 모서리 바깥은 터치를 받지 않는 캔버스.
///
/// `undoManager` 를 가로채지 않는다. PencilKit 은 그은 획을 자기가 찾은 매니저에 쌓고
/// 되돌리기도 그 매니저로 한다. 중간에서 다른 매니저를 쥐여 주면
/// 쌓이는 곳과 되돌리는 곳이 어긋나 되돌리기가 아무 일도 하지 않는다.
final class DoodleCanvasView: PKCanvasView {

    /// 메모지 모서리 바깥은 터치를 받지 않는다.
    ///
    /// 캔버스를 둥글게 자르는 것만으로는 부족하다. 자르기는 보이는 것만 가리고,
    /// 종이 밖을 눌러도 획은 그대로 만들어져 저장된다.
    /// 여기서 막아야 애초에 그려지지 않는다.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard super.point(inside: point, with: event) else { return false }
        return UIBezierPath(
            roundedRect: bounds,
            cornerRadius: DoodleMetrics.canvasCornerRadius
        ).contains(point)
    }
}
