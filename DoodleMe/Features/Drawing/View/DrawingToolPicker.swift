//
//  DrawingToolPicker.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/10/26.
//

import SwiftUI

struct DrawingToolPicker: View {

    let session: DrawingSession

    /// 버튼 하나가 차지하는 정사각형 한 변.
    /// 손끝으로 정확히 누를 수 있는 최소 크기이고, 앱의 다른 버튼도 이 값을 높이로 쓴다.
    static let buttonSide: CGFloat = 44

    var body: some View {
        // 무엇으로 그릴지를 앞에, 방금 한 일을 무르는 버튼을 뒤에 둔다.
        // 연필과 지우개, 되돌리기와 다시하기는 각각 짝이므로 갈라놓지 않는다.
        HStack(spacing: 12) {
            toolButton(icon: "pencil.tip", tool: .pen, label: "연필")
            toolButton(icon: "eraser.fill", tool: .eraser, label: "지우개")

            historyButton(
                icon: "arrow.uturn.backward",
                label: "실행 취소",
                isEnabled: session.canUndo
            ) {
                session.undo()
            }

            historyButton(
                icon: "arrow.uturn.right",
                label: "다시 실행",
                isEnabled: session.canRedo
            ) {
                session.redo()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.white, in: RoundedRectangle(cornerRadius: 30))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        .padding(.bottom, 30)
    }

    /// 지금 무엇으로 그릴지 고르는 버튼. 고른 쪽에 강조색 원이 깔린다.
    @ViewBuilder
    private func toolButton(icon: String, tool: DrawingSession.Tool, label: String) -> some View {
        let isSelected = session.tool == tool
        Button {
            session.tool = tool
        } label: {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(isSelected ? Color.white : .primary)
                .frame(width: Self.buttonSide, height: Self.buttonSide)
                .background(
                    isSelected ? Color.accentColor : Color.clear,
                    in: Circle()
                )
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// 되돌리기·다시하기 버튼. 할 수 없을 때는 흐리게 두고 눌리지 않는다.
    private func historyButton(
        icon: String,
        label: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(isEnabled ? Color.primary : .gray.opacity(0.4))
                .frame(width: Self.buttonSide, height: Self.buttonSide)
        }
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }
}
