//
//  DrawingSession.swift
//  DoodleMe
//

import CoreGraphics
import Foundation

/// 그리기 화면의 상태를 모두 담는다.
///
/// 획 목록·undo/redo·도구 선택·30초 카운트다운을 한곳에 모아,
/// 뷰끼리 `@Binding`을 여섯 개씩 주고받지 않아도 되게 한다.
@Observable
final class DrawingSession {

    enum Tool {
        case pencil
        case eraser
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

    /// 지우개가 획을 지우는 반경(pt).
    private static let eraserRadius: CGFloat = 5

    // MARK: - 그림

    private(set) var lines: [Line] = []
    var tool: Tool = .pencil

    private var undoStack: [[Line]] = []
    private var redoStack: [[Line]] = []
    /// 손가락이 화면에 닿아 있는 동안 true. 한 획당 undo 스냅샷을 한 번만 남기려고 쓴다.
    private var isStrokeInProgress = false

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - 단계 · 남은 시간

    private(set) var phase: Phase = .notStarted
    private(set) var remaining: TimeInterval = duration

    /// 그리기를 한 번이라도 시작했는지. "다음" 버튼 노출 조건.
    var hasStartedDrawing: Bool { remaining < Self.duration }

    // MARK: - 입력 처리

    func handleDrag(at point: CGPoint) {
        switch tool {
        case .pencil:
            if isStrokeInProgress {
                lines[lines.count - 1].points.append(point)
            } else {
                captureUndoSnapshot()
                lines.append(Line(points: [point]))
                isStrokeInProgress = true
            }

        case .eraser:
            let survivors = lines.filter { !$0.touches(point, within: Self.eraserRadius) }
            // 실제로 지워진 게 없으면 스냅샷도 남기지 않는다.
            guard survivors.count < lines.count else { return }
            if !isStrokeInProgress {
                captureUndoSnapshot()
                isStrokeInProgress = true
            }
            lines = survivors
        }
    }

    /// 손가락을 뗐을 때. 다음 획은 새 undo 스냅샷을 남긴다.
    func endStroke() {
        isStrokeInProgress = false
    }

    private func captureUndoSnapshot() {
        undoStack.append(lines)
        redoStack.removeAll()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(lines)
        lines = previous
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(lines)
        lines = next
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
        lines = []
        undoStack = []
        redoStack = []
        isStrokeInProgress = false
        tool = .pencil
        remaining = Self.duration
        phase = .notStarted
    }

    // MARK: - 카운트다운

    /// 뷰의 `.task`에서 호출한다. Task가 취소되면 카운트다운도 함께 멈추므로,
    /// 예전처럼 화면을 떠난 뒤에도 타이머가 계속 도는 일이 없다.
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
