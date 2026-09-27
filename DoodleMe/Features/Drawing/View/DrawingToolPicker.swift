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
    // TODO: DoodleMetrics.side(scale: canvasScale) 로 옮겨 탈 것.
    //       그리기 탭 담당자와 합의 후. 배율은 headerScale 이 아니라 canvasScale 이다.
    static let buttonSide: CGFloat = 44

    /// 넓은 화면에서 얼마나 키울지. 아이폰에서는 1 이라 지금까지와 같다.
    ///
    /// 값을 여기서 정하지 않고 받는다. 막대 높이가 `DrawingPage.toolPickerReserve` 로 들어가고
    /// 그 값이 다시 종이 배율의 입력이라, 이 파일이 스스로 배율을 정하면 순환이 생긴다.
    /// 무엇을 기준으로 키울지는 화면 전체를 보는 쪽이 정한다.
    var scale: CGFloat = 1

    /// 알약 안쪽 치수. 한 값만 키우면 버튼만 커지고 알약이 답답해진다.
    private static let buttonSpacing: CGFloat = 12
    private static let horizontalPadding: CGFloat = 16
    private static let verticalPadding: CGFloat = 8
    private static let cornerRadius: CGFloat = 30
    private static let bottomPadding: CGFloat = 30
    private static let glyphSize: CGFloat = 22

    /// 버튼 한 변. 아이폰에서는 `buttonSide` 그대로다.
    ///
    /// 나중에 `DoodleMetrics.side(scale:)` 로 옮겨 탈 때 이 한 줄만 갈아 끼우면 된다.
    private var side: CGFloat { max(Self.buttonSide, Self.buttonSide * scale) }

    var body: some View {
        // 무엇으로 그릴지를 앞에, 방금 한 일을 무르는 버튼을 뒤에 둔다.
        // 연필과 지우개, 되돌리기와 다시하기는 각각 짝이므로 갈라놓지 않는다.
        HStack(spacing: Self.buttonSpacing * scale) {
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
        .padding(.horizontal, Self.horizontalPadding * scale)
        .padding(.vertical, Self.verticalPadding * scale)
        .background(.white, in: RoundedRectangle(cornerRadius: Self.cornerRadius * scale))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        .padding(.bottom, Self.bottomPadding * scale)
    }

    /// 지금 무엇으로 그릴지 고르는 버튼. 고른 쪽에 강조색 원이 깔린다.
    @ViewBuilder
    private func toolButton(icon: String, tool: DrawingSession.Tool, label: String) -> some View {
        let isSelected = session.tool == tool
        Button {
            session.tool = tool
        } label: {
            Image(systemName: icon)
                .font(.system(size: Self.glyphSize * scale, weight: .medium))
                .foregroundStyle(isSelected ? Color.white : .primary)
                .frame(width: side, height: side)
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
                .font(.system(size: Self.glyphSize * scale, weight: .medium))
                .foregroundStyle(isEnabled ? Color.primary : .gray.opacity(0.4))
                .frame(width: side, height: side)
        }
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }
}
