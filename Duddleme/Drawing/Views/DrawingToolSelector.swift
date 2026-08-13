//
//  DrawingTool.swift
//  Duddleme
//
//  Created by Jaesung Lee on 8/13/26.
//

import SwiftUI
import PencilKit

// TODO: should be renamed to DrawingToolPicker
struct DrawingToolSelector: View {
    @Environment(\.undoManager) var undoManager
    @Binding var canvasView: PKCanvasView
    
    @Bindable var paint: Paint
    
    var canUndo: Bool {
        undoManager?.canUndo == true
    }
    
    var canRedo: Bool {
        undoManager?.canRedo == true
    }
    
    var body: some View {
        HStack(spacing: 28) {
            
            // Undo
            Button {
                guard canUndo else { return }
                undoManager?.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(canUndo ? Color.primary : Color.gray.opacity(0.4))
            }
            .disabled(!canRedo)
            
            // Pencil
            DrawingToolButton(systemImage: "pencil.tip", isSelected: paint.isUsingPen) {
                paint.selectPen()
            }
            
            // Eraser
            DrawingToolButton(systemImage: "eraser.fill", isSelected: !paint.isUsingPen) {
                paint.selectEraser()
            }
            
            // Redo
            Button {
                // 재실행 기록이 있을 때만 코드 실행
                guard canRedo else { return }
                undoManager?.redo()
            } label: {
                Image(systemName: "arrow.uturn.right")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(canRedo ? Color.primary : Color.gray.opacity(0.4))
            }
            .disabled(!canRedo)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .glassEffect()
    }
}

struct DrawingToolButton: View {
    let systemImage: String
    let isSelected: Bool
    let onSelected: () -> Void
    
    var body: some View {
        Button {
            onSelected()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 30, height: 30)
                .background(
                    isSelected ? Color.accentColor : Color.clear,
                    in: .rect(cornerRadius: 30)
                )
        }
    }
}

#Preview {
    @Previewable @State var canvasView = PKCanvasView()
    @Previewable @State var paint = Paint()
    
    DrawingToolSelector(canvasView: $canvasView, paint: paint)
}
