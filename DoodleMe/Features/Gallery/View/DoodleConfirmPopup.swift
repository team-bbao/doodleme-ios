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

    /// 창이 하려는 말. 시스템 alert 의 제목 자리에 해당한다.
    let title: String
    /// 제목을 거드는 한 줄. 없으면 제목만 뜬다.
    var message: String?
    /// 물러나는 쪽 버튼. 없으면 진행 버튼 하나가 폭을 다 쓴다.
    /// 묻는 창이 아니라 알리기만 하는 창이 그 꼴이다.
    var cancelTitle: String?
    var confirmTitle: String
    var onCancel: (() -> Void)?
    var onConfirm: () -> Void

    // Figma `Alert`(95:1179) 치수
    /// 카드 폭. 402 화면에서 좌우로 51 씩 남는다.
    private static let width: CGFloat = 300
    private static let cornerRadius: CGFloat = 34
    /// 버튼 높이. Figma 는 이 자리에 48 을 쓴다.
    private static let buttonHeight: CGFloat = 48
    /// 본문과 버튼 사이.
    private static let contentSpacing: CGFloat = 40
    /// 제목과 본문 사이.
    private static let titleSpacing: CGFloat = 6
    /// 글자 크기는 시스템 alert 과 맞춘다.
    ///
    /// 같은 화면에서 이 창과 시스템 alert(그림 삭제)이 번갈아 뜨는데,
    /// 크기가 다르면 같은 무게의 물음인데도 한쪽이 더 급해 보인다.
    /// 재 보니 시스템은 제목 17 / 본문 13 이었다.
    ///
    /// 굵기까지 따라가지는 않는다. 시스템 제목은 Semibold 지만
    /// Figma `Alert`(95:1179) 이 Regular 로 두고 있어 디자인 쪽을 따른다.
    private static let titleFontSize: CGFloat = 17
    private static let messageFontSize: CGFloat = 13

    var body: some View {
        VStack(spacing: Self.contentSpacing) {
            VStack(spacing: Self.titleSpacing) {
                Text(title)
                    // Figma `Alert`(95:1179): SF Pro Regular / 자간 -0.43 / 행높이 22
                    .font(.system(size: Self.titleFontSize))
                    .kerning(-0.43)
                    .lineSpacing(2)
                    .foregroundStyle(.black)

                if let message {
                    Text(message)
                        .font(.system(size: Self.messageFontSize))
                        .kerning(-0.43)
                        .foregroundStyle(.black)
                }
            }
            .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                // 물러나는 쪽이 왼쪽, 진행하는 쪽이 오른쪽.
                if let cancelTitle, let onCancel {
                    choice(cancelTitle, fill: Color.doodleControlFill, label: .black, action: onCancel)
                }
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
        VStack(spacing: 24) {
            DoodleConfirmPopup(
                title: "프로필 사진으로 설정하시겠습니까?",
                cancelTitle: "아니오",
                confirmTitle: "예",
                onCancel: { },
                onConfirm: { }
            )
            DoodleConfirmPopup(
                title: "사진 저장",
                message: "그림이 사진 앱에 저장됐어요.",
                confirmTitle: "확인",
                onConfirm: { }
            )
        }
    }
}
