//
//  DrawingSession.swift
//  DoodleMe
//

import Foundation
import PencilKit

/// 그리기 화면의 상태를 모두 담는다.
///
/// 획 관리와 undo/redo 는 PencilKit(`PKCanvasView`)이 맡고,
/// 여기서는 단계 전환·카운트다운·도구 선택과 캔버스에서 올라온 그림을 보관한다.
@Observable
final class DrawingSession {

    enum Tool {
        case pen
        case eraser

        /// 펜의 기준 굵기. 속도로 굵기를 다시 매길 때도 이 값을 기준으로 삼는다.
        static let penWidth: CGFloat = 3

        var pkTool: PKTool {
            switch self {
            case .pen:
                // 필압은 잉크 종류로 해결되지 않는다.
                // 저장된 획을 뜯어보니 force 가 0 이었다. 손가락 터치에는 힘 값이 없다.
                // 3D Touch 가 사라진 뒤로 아이폰은 손가락 압력을 재지 않는다.
                // 애플펜슬로 그리면 이 잉크도 굵기가 변한다.
                PKInkingTool(.pen, color: .black, width: Self.penWidth)
            case .eraser:
                // 예전 지우개와 같이 닿은 획을 통째로 지운다. 픽셀 단위로 지우려면 .bitmap.
                PKEraserTool(.vector)
            }
        }
    }

    /// 그리기 흐름의 단계.
    enum Phase {
        /// 포스트잇을 아직 떼지 않음
        case notStarted
        /// 30초 그리기
        case drawing
        /// 받는 사람·첫인상 문구 입력
        case memo
    }

    /// 한 번의 그리기에 주어지는 시간.
    static let duration: TimeInterval = 30

    // MARK: - 그림

    private(set) var drawing = PKDrawing()
    var tool: Tool = .pen

    /// 코드에서 캔버스 내용을 갈아끼웠을 때만 올라간다.
    /// 캔버스 쪽에서 이 값이 바뀐 걸 보고 `PKCanvasView.drawing` 을 덮어쓴다.
    /// 사용자가 그리는 중에는 올라가지 않으므로 되먹임 루프가 생기지 않는다.
    private(set) var drawingRevision = 0

    private(set) var canUndo = false
    private(set) var canRedo = false

    /// 캔버스가 들고 있는 전용 UndoManager. 캔버스가 만들어질 때 주입된다.
    /// 상태가 아니라 참조라서 관찰 대상에서 뺀다.
    @ObservationIgnored private weak var undoManager: UndoManager?

    /// 저장할 바이너리.
    var drawingData: Data { drawing.dataRepresentation() }

    /// 획이 하나라도 있는지.
    var hasDrawing: Bool { !drawing.strokes.isEmpty }

    // MARK: - 단계 · 남은 시간

    private(set) var phase: Phase = .notStarted
    private(set) var remaining: TimeInterval = duration

    /// 그리기를 한 번이라도 시작했는지. "다음" 버튼 노출 조건.
    var hasStartedDrawing: Bool { remaining < Self.duration }

    // MARK: - 캔버스 연동

    /// 캔버스가 만들어질 때 자신의 UndoManager 를 넘겨준다.
    func attach(undoManager: UndoManager?) {
        self.undoManager = undoManager
        refreshUndoState()
    }

    /// 사용자가 캔버스에 그리거나 지웠을 때 캔버스 쪽에서 호출한다.
    func canvasDidChange(drawing: PKDrawing) {
        self.drawing = drawing
        refreshUndoState()
    }

    func undo() {
        undoManager?.undo()
        refreshUndoState()
    }

    func redo() {
        undoManager?.redo()
        refreshUndoState()
    }

    func refreshUndoState() {
        canUndo = undoManager?.canUndo ?? false
        canRedo = undoManager?.canRedo ?? false
    }

    // MARK: - 단계 전환

    /// 포스트잇을 떼고 그리기를 시작한다.
    func beginDrawing() {
        phase = .drawing
    }

    /// 메모 입력 단계로 넘어간다.
    func beginMemo() {
        phase = .memo
    }

    /// 카운트다운만 처음으로 되돌린다. 그린 그림은 남는다.
    func restartTimer() {
        remaining = Self.duration
        phase = .notStarted
    }

    /// 그림과 시간을 모두 비운다.
    func reset() {
        drawing = PKDrawing()
        drawingRevision += 1
        canUndo = false
        canRedo = false
        tool = .pen
        remaining = Self.duration
        phase = .notStarted
    }

    // MARK: - 카운트다운

    /// 뷰의 `.task` 에서 호출한다. Task 가 취소되면 카운트다운도 함께 멈춘다.
    ///
    /// 남은 시간을 틱마다 빼지 않고 시계에서 경과 시간을 직접 재서 계산한다.
    /// 틱이 밀리거나 건너뛰어도 남은 시간이 어긋나지 않는다.
    func runCountdown() async {
        let clock = ContinuousClock()
        let startedAt = clock.now
        let startedFrom = remaining

        while remaining > 0 {
            do {
                try await Task.sleep(for: .milliseconds(50))
            } catch {
                return // 취소됨
            }
            remaining = max(0, startedFrom - (clock.now - startedAt).seconds)
        }

        // 30초를 다 쓰면 자동으로 메모 입력 단계로 넘어간다.
        if phase == .drawing {
            phase = .memo
        }
    }
}
