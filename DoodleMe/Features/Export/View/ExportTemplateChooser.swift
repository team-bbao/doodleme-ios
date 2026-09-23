//
//  ExportTemplateChooser.swift
//  DoodleMe
//

import SwiftUI

/// 어느 판으로 내보낼지 먼저 묻는 시트. Figma `iPhone 17 - 36` 의 `Frame 53`(424:1303).
///
/// **고르기보다 먼저 묻는다.** 판이 정해져야 몇 장을 고를 수 있는지가 정해지기 때문이다 —
/// 뒤에 물으면 여섯 장을 고르고 나서야 한 장짜리 판이었다는 것을 알게 된다.
///
/// 판을 글로만 늘어놓지 않고 **나올 카드를 그대로 보여 준다.**
/// 「그림 하나」·「그림 여러개」 라는 말만으로는 결과가 그려지지 않는데,
/// 여기서 고르는 것은 장수가 아니라 **카드의 모양**이다.
struct ExportTemplateChooser: View {

    /// 시트 제목에 들어가는 이름. Figma 는 `abcdefgskd._.` 를 예시로 두었다.
    let accountName: String
    /// 판을 골랐을 때. 시트는 호출한 쪽이 닫는다.
    let onPick: (ExportTemplate) -> Void
    /// 닫기(X).
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            header

            HStack(alignment: .top, spacing: Self.cardSpacing) {
                ForEach(ExportTemplate.allCases) { template in
                    card(for: template)
                }
            }
            .padding(.top, Self.cardTop)
        }
    }

    // MARK: - 머리말

    /// Figma `Frame 53`: X 는 (21, 19) 에 44, 제목은 가운데 (·, 31).
    ///
    /// 제목은 두 조각이다 — 계정 이름만 굵고 나머지는 보통이다.
    /// 어디로 나가는지가 이 시트의 요점이라 이름 쪽에 무게를 둔다.
    private var header: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: Self.titleGap) {
                Text(accountName)
                    .font(.system(size: Self.titleSize, weight: .semibold))
                Text("계정으로 공유하기")
                    .font(.system(size: Self.titleSize))
            }
            .tracking(Self.titleTracking)
            .foregroundStyle(Color.doodleTitle)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.top, Self.titleTop)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: Self.closeGlyph, weight: .medium))
                    .foregroundStyle(Color.doodlePrimary)
                    .frame(width: Self.closeSide, height: Self.closeSide)
                    .background(.white, in: Circle())
                    // Figma `Frame 6`: 0 4 20 검정 10%. SwiftUI 반경은 blur 의 절반.
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("닫기")
            .padding(.leading, Self.closeLeading)
            .padding(.top, Self.closeTop)
        }
    }

    // MARK: - 판 하나

    /// 미리보기 한 장과 그 아래 단추. Figma `Frame 62`(424:1840) · `Frame 63`(424:1851).
    ///
    /// 미리보기는 **디자이너가 구워 둔 그림**이다. 살아 있는 카드를 줄여 넣지 않는다 —
    /// 이 시트는 고르기 **전에** 뜨므로 아직 넣을 그림이 없고,
    /// 여기서 보여 줄 것은 「내 그림이 어떻게 나오는가」가 아니라 「판이 어떻게 생겼는가」다.
    ///
    /// **미리보기와 단추가 한 덩이로 눌린다.** 단추만 살아 있던 때에는
    /// 화면의 거의 전부를 차지하는 그림이 눈길을 끌면서 아무 반응도 하지 않아,
    /// 32 짜리 알약을 따로 겨눠야 했다. 고르는 대상은 판이지 글자가 아니다.
    private func card(for template: ExportTemplate) -> some View {
        Button {
            onPick(template)
        } label: {
            VStack(spacing: Self.previewToButton) {
                Image(template.previewAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: Self.cardWidth, height: Self.previewHeight)
                    .clipShape(RoundedRectangle(cornerRadius: Self.previewCorner))
                    // Figma: 0 4 20 검정 20%. SwiftUI 반경은 blur 의 절반.
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 4)

                Text(template.title)
                    .font(.system(size: Self.buttonFont, weight: .semibold))
                    .tracking(Self.buttonTracking)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, Self.buttonInset)
                    .frame(height: Self.buttonHeight)
                    .background(Color.doodlePrimary, in: Capsule())
            }
            .frame(width: Self.cardWidth)
            // 그림과 알약 **사이의 빈 틈(35)까지** 받는다. 덩이 하나로 읽히게 하려는 것이다.
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(template.title)
    }

    // MARK: - Figma 좌표 (424:1303)

    /// 제목 줄. `Frame 54` 가 시트 위에서 31.
    private static let titleTop: CGFloat = 31
    private static let titleSize: CGFloat = 14
    private static let titleGap: CGFloat = 4
    private static let titleTracking: CGFloat = -0.43

    /// 닫기. `Frame 6` 이 (21, 19) 에 44.
    private static let closeLeading: CGFloat = 21
    private static let closeTop: CGFloat = 19
    private static let closeSide: CGFloat = 44
    private static let closeGlyph: CGFloat = 17

    /// 판 둘이 시작하는 높이. 폭 146, 사이 33 은 Figma `Frame 62`(31, 397) · `Frame 63`(210, 397).
    ///
    /// **세로는 Figma 를 참고로만 본다.**
    /// Figma 는 시트(801) 안에서 위 327 · 아래 138 로 판을 아래쪽에 몰아 두었는데,
    /// 실제로 띄워 보니 제목과 판 사이가 통째로 비어 화면이 반쯤 빈 것처럼 보였다.
    /// 시트 안의 상대 배치는 Figma 와 1.4 안에서 맞았으므로, 자리가 틀린 것이 아니라
    /// 도안 자체가 그렇게 그려져 있던 것이다.
    ///
    /// 그래서 이 값만 Figma 를 따르지 않고 **위아래가 고르게** 잡았다.
    /// 구운 화면에서 재면 제목 아래 212 · 단추 아래 204 로 거의 같다.
    ///
    /// 이 값이 시트 윗변에서 그대로 재지지 않는다 — 배경이 안전영역을 무시하면서
    /// ZStack 이 시트의 보이는 윗변보다 24 위에서 시작한다. 그래서 계산으로 얻은 246 이
    /// 화면에서는 약 284 에 앉는다. 눈으로 재 맞춘 값이라 구조를 바꾸면 다시 재야 한다.
    private static let cardTop: CGFloat = 246
    private static let cardWidth: CGFloat = 146
    private static let cardSpacing: CGFloat = 33

    /// 미리보기 146x269, 모서리 10.
    private static let previewHeight: CGFloat = 269
    private static let previewCorner: CGFloat = 10
    /// 미리보기 아랫변에서 단추까지.
    private static let previewToButton: CGFloat = 35

    /// 단추. 높이 32, 좌우 10, `#424242` 알약에 SF Pro Semibold 15 · 자간 -1.
    private static let buttonHeight: CGFloat = 32
    private static let buttonInset: CGFloat = 10
    private static let buttonFont: CGFloat = 15
    private static let buttonTracking: CGFloat = -1
}

private extension ExportTemplate {
    /// 시트에 걸리는 미리보기 그림. Figma `Frame 55` 에서 그대로 가져왔다.
    var previewAsset: ImageResource {
        switch self {
        case .single: .templatePreviewSingle
        case .multiple: .templatePreviewMulti
        }
    }
}

#Preview {
    ExportTemplateChooser(accountName: "abcdefgskd._.", onPick: { _ in }, onClose: {})
}
