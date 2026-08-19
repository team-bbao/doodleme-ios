//
//  DoodleConfirmPopup.swift
//  DoodleMe
//

import SwiftUI

/// 예/아니오를 묻는 앱 전용 확인창. Figma `iPhone 17 - 16` 의 `Alert`(95:1179) 기준.
///
/// 시스템 `alert` 를 쓰지 않는 이유가 있다.
/// 이 확인창은 고른 카드를 가리지 않는 자리에 얹혀야 하고,
/// 유리 재질과 34 반경이 앱의 다른 카드들과 같은 결이어야 한다.
/// 시스템 alert 는 자리도 재질도 정할 수 없다.
struct DoodleConfirmPopup: View {

    let message: String
    var cancelTitle: String
    var confirmTitle: String
    var onCancel: () -> Void
    var onConfirm: () -> Void

    // Figma `Alert`(95:1179) 치수
    /// 카드 폭. 402 화면에서 좌우로 51 씩 남는다.
    private static let width: CGFloat = 300
    private static let cornerRadius: CGFloat = 34
    /// 버튼 높이. Figma 는 이 자리에 48 을 쓴다.
    private static let buttonHeight: CGFloat = 48
    /// 본문과 버튼 사이.
    private static let contentSpacing: CGFloat = 40

    var body: some View {
        VStack(spacing: Self.contentSpacing) {
            Text(message)
                // Figma: SF Pro Regular 17 / 자간 -0.43 / 행높이 22
                .font(.system(size: 17))
                .kerning(-0.43)
                .lineSpacing(2)
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                // 물러나는 쪽이 왼쪽, 진행하는 쪽이 오른쪽.
                choice(cancelTitle, fill: Color.doodleControlFill, label: .black, action: onCancel)
                choice(confirmTitle, fill: Color.doodlePrimary, label: .white, action: onConfirm)
            }
        }
        .padding(.top, 39)
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .frame(width: Self.width)
        .glassEffect(.regular, in: .rect(cornerRadius: Self.cornerRadius))
        .overlay {
            // Figma 의 0.5px `#DBDBDB` 테두리. 유리 위에 얹혀야 경계가 보인다.
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .strokeBorder(Color.doodlePopupBorder, lineWidth: 0.5)
        }
        // Figma 그림자 blur 48 → SwiftUI radius 는 그 절반.
        .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    private func choice(
        _ title: String,
        fill: Color,
        label: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .kerning(-0.43)
                .foregroundStyle(label)
                .frame(maxWidth: .infinity)
                .frame(height: Self.buttonHeight)
                .background(fill, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.doodleBackground.ignoresSafeArea()
        DoodleConfirmPopup(
            message: "프로필 사진으로 설정하시겠습니까?",
            cancelTitle: "아니오",
            confirmTitle: "예"
        ) { } onConfirm: { }
    }
}
