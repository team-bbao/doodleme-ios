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

    /// 되돌리기 기록. 그림 전체를 통째로 담아 둔다.
    ///
    /// PencilKit 의 `UndoManager` 를 쓰지 않는다.
    /// 손가락 굵기를 다시 매기려고 매 획마다 캔버스의 그림을 통째로 갈아끼우는데,
    /// 그 대입이 PencilKit 의 되돌리기 스택과 엉켜 `undo()` 가 아무 일도 하지 않았다.
    /// 우리가 이미 그림 전체를 들고 있으니 직접 쌓는 편이 단순하고 확실하다.
    @ObservationIgnored private var undoStack: [PKDrawing] = []
    @ObservationIgnored private var redoStack: [PKDrawing] = []

    /// 되짚을 수 있는 최대 횟수. 30초 안에 이보다 많이 그을 일은 없다.
    private static let historyLimit = 50

    /// 저장할 바이너리.
    var drawingData: Data { drawing.dataRepresentation() }

    // MARK: - 단계 · 남은 시간

    private(set) var phase: Phase = .notStarted
    private(set) var remaining: TimeInterval = duration

    /// 그리기를 한 번이라도 시작했는지. "다음" 버튼 노출 조건.
    var hasStartedDrawing: Bool { remaining < Self.duration }

    // MARK: - 캔버스 연동

    /// 사용자가 캔버스에 그리거나 지웠을 때 캔버스 쪽에서 호출한다.
    ///
    /// 우리가 캔버스를 갈아끼워서 생긴 변경은 여기로 오지 않는다.
    /// 캔버스 쪽에서 걸러내므로, 여기 오는 건 모두 사용자가 한 편집이다.
    func canvasDidChange(drawing: PKDrawing) {
        undoStack.append(self.drawing)
        if undoStack.count > Self.historyLimit { undoStack.removeFirst() }
        // 새로 그은 순간 앞으로 갈 길은 사라진다.
        redoStack.removeAll()

        self.drawing = drawing
        refreshUndoState()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(drawing)
        apply(previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(drawing)
        apply(next)
    }

    /// 기록에서 꺼낸 그림을 화면에 되돌려 놓는다.
    private func apply(_ restored: PKDrawing) {
        drawing = restored
        // 캔버스는 이 값이 바뀐 걸 보고 자기 그림을 덮어쓴다.
        drawingRevision += 1
        refreshUndoState()
    }

    private func refreshUndoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
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

    /// 그림과 시간을 모두 비운다.
    func reset() {
        drawing = PKDrawing()
        drawingRevision += 1
        undoStack.removeAll()
        redoStack.removeAll()
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
