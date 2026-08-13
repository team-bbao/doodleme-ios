//
//  Drawing.swift
//  Duddleme
//
//  Created by Jaesung Lee on 8/13/26.
//

import Observation

@Observable
final class Drawing {
    var selectedTool: DrawingTool = .pen
    
    // MARK: PencilKit
    
    // MARK: - 그림 데이터
    /// 현재 그림 (Line 들로 표현)
    var lines: [Line] = []
    /// 재실행 기록
    var redoStack: [[Line]] = [[]]
    /// 실행취소 기록
    var undoStack: [[Line]] = [[]]
    
    // MARK: - 카드 뒷면
    /// 수신자 이름
    var recipientName = ""
    /// 입력한 텍스트
    var message = ""
}

import PencilKit

@Observable
final class Paint {
    var selectedTool: DrawingTool = .pen
    var drawing = PKDrawing()
    var currentTool: PKTool = PKInkingTool(.pen, color: .accent, width: 2)
    var isUsingPen: Bool {
        self.currentTool is PKInkingTool
    }
    
    var asData: Data {
        drawing.dataRepresentation()
    }
    
    // MARK: - 카드 뒷면
    /// 수신자 이름
    var recipientName = ""
    /// 입력한 텍스트
    var message = ""
    
    func selectPen() {
        self.currentTool = PKInkingTool(.pen, color: .accent, width: 2)
    }
    
    func selectEraser() {
        self.currentTool = PKEraserTool(.bitmap)
    }
}
