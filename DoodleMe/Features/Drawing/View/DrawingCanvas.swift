//
//  DrawingCanvas.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/10/26.
//

import PencilKit
import SwiftUI

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

        session.attach(undoManager: canvas.undoManager)
        return canvas
    }

    func updateUIView(_ canvas: DoodleCanvasView, context: Context) {
        canvas.tool = session.tool.pkTool

        // 코드에서 그림을 갈아끼운 경우(초기화)에만 캔버스를 덮어쓴다.
        // 사용자가 그리는 중에 덮어쓰면 획이 끊기므로 revision 으로 구분한다.
        if context.coordinator.appliedRevision != session.drawingRevision {
            context.coordinator.appliedRevision = session.drawingRevision
            canvas.drawing = session.drawing
            canvas.undoManager?.removeAllActions()
            session.refreshUndoState()
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let session: DrawingSession
        var appliedRevision = 0

        init(session: DrawingSession) {
            self.session = session
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            session.canvasDidChange(drawing: canvasView.drawing)
        }
    }
}

/// 전용 `UndoManager` 를 갖는 캔버스.
///
/// 기본 `UIView.undoManager` 는 응답자 체인을 타고 올라가 윈도우의 것을 쓴다.
/// 그러면 그림 되돌리기가 텍스트 필드 편집 되돌리기와 같은 스택을 공유해 서로 간섭한다.
/// 캔버스만의 스택을 두어 그림 undo/redo 를 독립시킨다.
final class DoodleCanvasView: PKCanvasView {
    private let canvasUndoManager = UndoManager()

    override var undoManager: UndoManager? {
        canvasUndoManager
    }
}
