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

private struct CanvasRepresentable: UIViewRepresentable {

    let session: DrawingSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeUIView(context: Context) -> CanvasContainerView {
        let container = CanvasContainerView()
        let canvas = container.canvas
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

        container.live.baseWidth = DrawingSession.Tool.penWidth
        context.coordinator.liveView = container.live

        // 손끝을 따라가려면 전용 추적기가 필요하다.
        //
        // PencilKit 의 `drawingGestureRecognizer` 에 타깃을 붙여 보면 `.began` 만 오고
        // `.changed` 가 오지 않는다. 시작만 알고 어디로 가는지는 알 수 없어 쓸 수 없다.
        let tracker = TouchTrackingGestureRecognizer()
        tracker.delegate = context.coordinator
        tracker.onTouches = { [weak coordinator = context.coordinator, weak tracker] actual, predicted in
            coordinator?.trackTouches(
                actual: actual,
                predicted: predicted,
                isFirst: tracker?.state == .began
            )
        }
        // 캔버스가 받을 터치를 가로채거나 미루지 않는다. 그리기는 그대로 PencilKit 이 한다.
        tracker.cancelsTouchesInView = false
        tracker.delaysTouchesBegan = false
        tracker.delaysTouchesEnded = false
        container.addGestureRecognizer(tracker)

        return container
    }

    func updateUIView(_ container: CanvasContainerView, context: Context) {
        let canvas = container.canvas
        canvas.tool = session.tool.pkTool

        // 코드에서 그림을 갈아끼운 경우(초기화·되돌리기)에만 캔버스를 덮어쓴다.
        // 사용자가 그리는 중에 덮어쓰면 획이 끊기므로 revision 으로 구분한다.
        if context.coordinator.appliedRevision != session.drawingRevision {
            context.coordinator.appliedRevision = session.drawingRevision
            context.coordinator.apply(session.drawing, to: canvas)
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
        let session: DrawingSession
        var appliedRevision = 0

        /// 굵기를 이미 매긴 획의 수.
        private var shapedStrokeCount = 0
        /// 우리가 그림을 갈아끼우는 중인지.
        ///
        /// 그 변경은 사용자의 편집이 아니므로 되돌리기 기록에 쌓으면 안 되고,
        /// 굵기를 다시 매길 일도 없다. 델리게이트가 되울려도 그냥 흘려보낸다.
        private var isApplyingOurOwnChange = false

        /// 긋는 동안의 획을 그리는 층. `makeUIView` 에서 꽂아 준다.
        weak var liveView: LiveStrokeView?

        init(session: DrawingSession) {
            self.session = session
        }

        /// PencilKit 의 그리기 제스처와 나란히 인식되게 한다.
        /// 한쪽이 다른 쪽을 밀어내면 그림이 그려지지 않거나 미리보기가 멈춘다.
        nonisolated func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }

        /// 손끝을 따라가며 미리보기를 잇는다.
        ///
        /// 획을 만들고 다듬는 일은 그대로 PencilKit 이 한다.
        /// 우리는 같은 손끝을 보며 굵기만 미리 그려 보여 줄 뿐이다.
        ///
        /// 손을 뗀 자리에서 지우지 않는다.
        /// 확정된 획이 화면에 올라오기 전에 지우면 획이 한 번 깜빡인다.
        func trackTouches(actual: [CGPoint], predicted: [CGPoint], isFirst: Bool) {
            let now = CACurrentMediaTime()
            if isFirst, let first = actual.first {
                liveView?.begin(at: first, time: now)
                liveView?.extend(through: Array(actual.dropFirst()), predicted: predicted, time: now)
            } else {
                liveView?.extend(through: actual, predicted: predicted, time: now)
            }
        }

        /// 세션이 들고 있는 그림을 캔버스에 그대로 옮긴다. 초기화와 되돌리기가 이 길로 온다.
        func apply(_ drawing: PKDrawing, to canvas: PKCanvasView) {
            isApplyingOurOwnChange = true
            canvas.drawing = drawing
            isApplyingOurOwnChange = false

            // 세어둔 획 수도 함께 맞춘다.
            // 빠뜨리면 이후에 그린 획이 "이미 처리한 만큼" 에 미치지 못해
            // 굵기가 다시 매겨지지 않는다. 필압이 조용히 죽는다.
            shapedStrokeCount = drawing.strokes.count
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // 우리가 갈아끼운 변경이 되울려 온 것이면 편집이 아니다.
            guard !isApplyingOurOwnChange else { return }

            let count = canvasView.drawing.strokes.count

            // 획이 늘었을 때만 굵기를 다시 매긴다.
            // 지우개로 줄었으면 세어둔 수만 맞춰 두고 넘어간다.
            if count > shapedStrokeCount {
                isApplyingOurOwnChange = true
                canvasView.drawing = canvasView.drawing
                    .withVelocityBasedWidth(baseWidth: DrawingSession.Tool.penWidth)
                isApplyingOurOwnChange = false
            }
            shapedStrokeCount = count

            // 확정된 획이 화면에 올라왔으니 미리보기는 물러난다.
            liveView?.finish()

            session.canvasDidChange(drawing: canvasView.drawing)
        }
    }
}

/// 전용 `UndoManager` 를 갖는 캔버스.
///
/// 되돌리기는 `DrawingSession` 이 스냅샷으로 직접 관리한다. 이 매니저는 쓰지 않는다.
/// 그래도 두는 이유는 **막기 위해서**다.
/// 기본 `UIView.undoManager` 는 응답자 체인을 타고 올라가 윈도우의 것을 쓰는데,
/// 그대로 두면 PencilKit 이 등록한 획 편집이 메모 화면의 텍스트 되돌리기와 같은 스택에 쌓인다.
/// 여기서 받아 두면 앱의 다른 되돌리기가 그림에 오염되지 않는다.
final class DoodleCanvasView: PKCanvasView {
    private let canvasUndoManager = UndoManager()

    override var undoManager: UndoManager? {
        canvasUndoManager
    }

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


/// 캔버스와 그 위에 얹히는 미리보기를 함께 담는 그릇.
///
/// 미리보기를 `PKCanvasView` 의 하위 뷰로 넣으면 PencilKit 이 그리는 층 밑으로 들어가
/// 화면에 나타나지 않는다. 같은 높이의 형제로 두고 순서로 위에 올린다.
final class CanvasContainerView: UIView {

    let canvas = DoodleCanvasView()
    let live = LiveStrokeView(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)
        for child in [canvas, live] as [UIView] {
            child.translatesAutoresizingMaskIntoConstraints = false
            addSubview(child)
            NSLayoutConstraint.activate([
                child.leadingAnchor.constraint(equalTo: leadingAnchor),
                child.trailingAnchor.constraint(equalTo: trailingAnchor),
                child.topAnchor.constraint(equalTo: topAnchor),
                child.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// 손끝의 움직임을 그대로 알려 주는 제스처 추적기.
///
/// 문턱값도 방향 판정도 없다. 닿으면 `began`, 움직이면 `changed`, 떼면 `ended` 를 낸다.
/// `UIPanGestureRecognizer` 는 어느 정도 끌어야 시작을 알리므로 획의 첫머리를 놓친다.
///
/// 위치를 하나만 넘기지 않는다.
/// iOS 는 화면을 한 번 갱신하는 사이에 손끝을 여러 번 읽어 **모아서** 준다.
/// 마지막 하나만 쓰면 그 사이의 궤적이 통째로 빠져 선이 각지고 손이 간 길과 달라진다.
/// 갈 자리를 미리 셈해 둔 **예측** 위치도 함께 넘긴다. 그만큼 선이 손끝에 붙는다.
final class TouchTrackingGestureRecognizer: UIGestureRecognizer {

    /// 실제로 지나온 자리들과, 앞으로 갈 것으로 셈한 자리들.
    var onTouches: (([CGPoint], [CGPoint]) -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        state = .began
        report(touches, event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        state = .changed
        report(touches, event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        state = .cancelled
    }

    private func report(_ touches: Set<UITouch>, _ event: UIEvent) {
        guard let touch = touches.first, let view else { return }
        let actual = (event.coalescedTouches(for: touch) ?? [touch]).map { $0.location(in: view) }
        let predicted = (event.predictedTouches(for: touch) ?? []).map { $0.location(in: view) }
        onTouches?(actual, predicted)
    }
}
