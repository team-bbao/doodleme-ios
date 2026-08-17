//
//  DrawingToolPicker.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/10/26.
//

import SwiftUI

struct DrawingToolPicker: View {

    let session: DrawingSession

    var body: some View {
        HStack(spacing: 28) {

            Button {
                session.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(session.canUndo ? Color.primary : .gray.opacity(0.4))
            }
            .disabled(!session.canUndo)
            .accessibilityLabel("실행 취소")

            toolButton(icon: "pencil.tip", tool: .pen, label: "연필")
            toolButton(icon: "eraser.fill", tool: .eraser, label: "지우개")

            Button {
                session.redo()
            } label: {
                Image(systemName: "arrow.uturn.right")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(session.canRedo ? Color.primary : .gray.opacity(0.4))
            }
            .disabled(!session.canRedo)
            .accessibilityLabel("다시 실행")
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background(.white, in: RoundedRectangle(cornerRadius: 30))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        .padding(.bottom, 30)
    }

    @ViewBuilder
    private func toolButton(icon: String, tool: DrawingSession.Tool, label: String) -> some View {
        let isSelected = session.tool == tool
        Button {
            session.tool = tool
        } label: {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(isSelected ? Color.white : .primary)
                .frame(width: 30, height: 30)
                .background(isSelected ? Color.accentColor : Color.clear,
                            in: RoundedRectangle(cornerRadius: 30))
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
