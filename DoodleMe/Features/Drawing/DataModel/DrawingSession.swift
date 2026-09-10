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

        /// 펜 굵기.
        static let penWidth: CGFloat = 3

        var pkTool: PKTool {
            switch self {
            case .pen:
                // 손가락 터치에는 힘 값이 없어 굵기가 일정하다.
                // 3D Touch 가 사라진 뒤로 아이폰은 손가락 압력을 재지 않는다.
                // 애플펜슬로 그리면 이 잉크도 필압에 따라 굵기가 변한다.
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

    private(set) var canUndo = false
    private(set) var canRedo = false

    /// 되돌리기·다시하기 버튼이 눌린 횟수.
    ///
    /// 되돌리기는 `PKCanvasView` 가 가진 `UndoManager` 가 한다.
    /// 세션에서 캔버스를 직접 부를 길이 없으니 누른 횟수만 올려 두면,
    /// 캔버스가 자기가 아는 횟수와 달라진 것을 보고 한 번씩 되돌린다.
    private(set) var undoRequest = 0
    private(set) var redoRequest = 0

    /// 저장할 바이너리.
    var drawingData: Data { drawing.dataRepresentation() }

    // MARK: - 단계 · 남은 시간

    private(set) var phase: Phase = .notStarted
    private(set) var remaining: TimeInterval = duration

    /// 그리기를 한 번이라도 시작했는지. "다음" 버튼 노출 조건.
    var hasStartedDrawing: Bool { remaining < Self.duration }

    // MARK: - 캔버스 연동

    /// 캔버스의 그림이 바뀔 때마다 캔버스 쪽에서 호출한다.
    ///
    /// 사용자가 그은 것이든 되돌리기로 돌아온 것이든, 지금 캔버스에 있는 그대로를 받는다.
    /// 저장할 때 쓸 사본을 한 벌 들고 있을 뿐, 이 값으로 캔버스를 되돌리지는 않는다.
    func canvasDidChange(drawing: PKDrawing) {
        self.drawing = drawing
    }

    /// 캔버스가 자기 `UndoManager` 사정을 알려 준다. 버튼의 활성 여부가 여기에 달렸다.
    ///
    /// 값이 그대로일 때는 넘어간다. 캔버스는 화면이 갱신될 때마다 이 길을 지나는데,
    /// 같은 값이라도 대입하면 그것이 다시 화면 갱신을 부른다.
    func updateHistoryState(canUndo: Bool, canRedo: Bool) {
        if self.canUndo != canUndo { self.canUndo = canUndo }
        if self.canRedo != canRedo { self.canRedo = canRedo }
    }

    func undo() {
        undoRequest += 1
    }

    func redo() {
        redoRequest += 1
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
        undoRequest = 0
        redoRequest = 0
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
            // 초기화로 단계가 바뀐 뒤에도 계속 쓰면,
            // 방금 되돌려 놓은 남은 시간을 예전 값으로 덮어버린다.
            // 취소가 전달되기까지의 짧은 틈을 막는다.
            guard phase == .drawing else { return }
            remaining = max(0, startedFrom - (clock.now - startedAt).seconds)
        }

        // 30초를 다 쓰면 자동으로 메모 입력 단계로 넘어간다.
        if phase == .drawing {
            phase = .memo
        }
    }
}
