//
//  GallerySortMenu.swift
//  DoodleMe
//

import SwiftUI

/// 정렬 순서를 고르는 메뉴. Figma `iPhone 17 - 25` 의 `Menu`(222:1138).
///
/// **시스템 `Menu` 를 쓰지 않고 직접 그린다.**
///
/// 시스템 메뉴는 자리·폭·글자 크기·안쪽 여백을 iOS 가 정하고 손댈 길을 주지 않는다.
/// 그래서 Figma 가 정한 250x100, 모서리 34, 글자 17 을 넣을 데가 없었다 —
/// 실제로 폭이 모자라 「최근 추가된 순으로 정렬」이 두 줄로 접혔고,
/// 뜨는 자리도 Figma(13, 118)와 달랐다.
///
/// 대신 시스템 메뉴가 거저 주던 것들을 여기서 챙긴다 —
/// 바깥을 누르면 닫히고, 열고 닫을 때 모서리에서 자라나며, 고른 항목을 낭독기에 알린다.
struct GallerySortMenu: View {

    @Binding var sortOrder: Int
    /// 고르고 나면 닫는다.
    let onPick: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(GallerySortOrder.allCases, id: \.rawValue) { order in
                row(for: order)
            }
        }
        .padding(.vertical, Self.verticalPadding)
        .frame(width: Self.width)
        // **유리를 입힌다.** Figma 가 이 판을 `Liquid Glass - Regular - Medium` 으로 두었다.
        //
        // `.regularMaterial` 과 다르다 — 재질은 뒤를 흐리기만 하지만 유리는 뒤를 굴절시키고
        // 가장자리에 빛을 물린다. 확인창(`DoodleConfirmPopup`)이 같은 모양을 같은 방식으로 쓴다.
        .glassEffect(.regular, in: .rect(cornerRadius: Self.corner))
        // Figma `Fill + Shadow` 의 0.5 `#DBDBDB` 테두리. 유리 위에 얹혀야 경계가 보인다.
        .overlay {
            RoundedRectangle(cornerRadius: Self.corner)
                .strokeBorder(Color.doodlePopupBorder, lineWidth: 0.5)
        }
        // Figma: 0 8 48 검정 25%. SwiftUI 반경은 blur 의 절반.
        .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
    }

    /// 항목 한 줄. Figma `Item`(222:1141) — 왼쪽 6 · 오른쪽 8, 안에 gap 8.
    ///
    /// 체크는 **글자 앞의 고정 칸(28)** 에 든다. 고르지 않은 줄은 그 칸을 비워 두므로
    /// 두 줄의 글자가 같은 x 에서 시작한다 — 체크가 붙고 떨어져도 글이 움직이지 않는다.
    private func row(for order: GallerySortOrder) -> some View {
        let isOn = order.rawValue == sortOrder

        return Button {
            sortOrder = order.rawValue
            onPick()
        } label: {
            HStack(spacing: Self.leadingGap) {
                // **고르지 않은 줄도 같은 칸을 쓴다.**
                // `if` 로 빼면 칸이 무너져 둘째 줄 글자가 왼쪽으로 튀어나온다 —
                // 그러면 체크가 붙고 떨어질 때마다 글이 좌우로 움직인다.
                Image(systemName: "checkmark")
                    .font(.system(size: Self.fontSize))
                    .opacity(isOn ? 1 : 0)
                    .frame(width: Self.checkSlot)

                Text(order.title)
                    .font(.system(size: Self.fontSize))
                    .tracking(Self.tracking)
                    .lineLimit(1)
                    // Figma 의 행높이 20 을 17 짜리 글자에 맞춘다.
                    .frame(height: Self.lineHeight)

                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.doodleTitle)
            .padding(.leading, Self.itemLeading)
            .padding(.trailing, Self.itemTrailing)
            .padding(.vertical, Self.itemVertical)
            .padding(.horizontal, Self.sidePadding)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    // MARK: - Figma 좌표 (222:1138)

    /// 메뉴 한 장. 높이는 줄 둘(40씩) + 위아래 10 이라 100 이 된다.
    static let width: CGFloat = 250
    private static let corner: CGFloat = 34
    /// `Menu` 의 `py`.
    private static let verticalPadding: CGFloat = 10
    /// `Menu Items` 의 `px`.
    private static let sidePadding: CGFloat = 16
    /// `Item` 의 `pl` · `pr`.
    private static let itemLeading: CGFloat = 6
    private static let itemTrailing: CGFloat = 8
    /// `Label and Subtitle` 의 `py`. 20 + 10 + 10 = 줄 높이 40.
    private static let itemVertical: CGFloat = 10
    /// 체크 칸과 글자 사이.
    private static let leadingGap: CGFloat = 8
    /// 체크가 드는 칸.
    private static let checkSlot: CGFloat = 28

    /// `menus/menu-items/title-font-size` · `title-line-height`.
    private static let fontSize: CGFloat = 17
    private static let lineHeight: CGFloat = 20
    private static let tracking: CGFloat = -0.43
}

#Preview {
    ZStack {
        Color.doodleBackground
        GallerySortMenu(sortOrder: .constant(0), onPick: {})
    }
}
