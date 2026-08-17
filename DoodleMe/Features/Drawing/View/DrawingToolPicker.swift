//
//  DrawingToolPicker.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/10/26.
//

import SwiftUI

struct DrawingToolPicker: View {
    @Binding var selectedTab: Int
    @Binding var lines: [Line]
    @Binding var redoStack: [[Line]]
    @Binding var undoStack: [[Line]]
    @Binding var goNext: Bool

    var body: some View {
        if !goNext {
            HStack(spacing: 28) {

                // Undo
                Button {
                    if let prev = undoStack.popLast() {
                        redoStack.append(lines)
                        lines = prev
                    }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(undoStack.isEmpty ? .gray.opacity(0.4) : .primary)
                }
                .disabled(undoStack.isEmpty)

                // Pencil
                toolButton(icon: "pencil.tip", tag: 0)

                // Eraser
                toolButton(icon: "eraser.fill", tag: 1)

                // Redo
                Button {
                    if let next = redoStack.popLast() {
                        undoStack.append(lines)
                        lines = next
                    }
                } label: {
                    Image(systemName: "arrow.uturn.right")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(redoStack.isEmpty ? .gray.opacity(0.4) : .primary)
                }
                .disabled(redoStack.isEmpty)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(.white, in: RoundedRectangle(cornerRadius: 30))
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
            .padding(.bottom, 30)
        }
    }

    @ViewBuilder
    func toolButton(icon: String, tag: Int) -> some View {
        let isSelected = selectedTab == tag
        Button {
            selectedTab = tag
        } label: {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 30, height: 30)
                .background(isSelected ? Color.accentColor : Color.clear,
                            in: RoundedRectangle(cornerRadius: 30))
        }
    }
}
