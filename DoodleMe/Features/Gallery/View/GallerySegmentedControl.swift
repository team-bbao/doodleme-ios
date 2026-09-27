//
//  GallerySegmentedControl.swift
//  DoodleMe
//

import SwiftUI

/// 「나를 그린 / 내가 그린」을 고르는 막대. Figma `iPhone 17 - 12` 의 `Segmented Control`(222:1199).
///
/// 시스템 `Picker(.segmented)` 를 쓴다.
/// 예전에는 흰 트랙에 회색 캡슐을 직접 그렸는데, 디자인이 시스템 컴포넌트로 바뀌었다.
/// 손으로 그리면 겉은 닮아도 눌림·전환·손쉬운 사용 동작이 시스템과 어긋난다.
///
/// 칸의 **순서와 뜻**은 `GallerySection` 이 정한다.
struct GallerySegmentedControl: View {

    @Binding var selection: Int

    /// 넓은 화면에서 얼마나 키울지. 아이폰에서는 1 이라 지금까지와 같다.
    var scale: CGFloat = 1

    /// Figma `222:1199` 의 높이. 시스템 기본값보다 조금 높다.
    /// 제목 줄에 세울 때 버튼 셋과 세로 가운데를 맞추려고 `GalleryPage` 도 이 값을 본다.
    static let trackHeight: CGFloat = 35

    /// 본문 폭(362)에서 좌우로 더 들어가는 정도.
    ///
    /// Figma 는 이 막대만 x=21 폭 359 로 두어, 카드 그리드(x=20 폭 362)보다 안쪽에 있다.
    /// 그리드까지 함께 옮기지 않도록 이 막대에서만 좁힌다.
    private static let extraInset: CGFloat = 1.5

    var body: some View {
        Picker("보고 있는 그림", selection: $selection) {
            ForEach(GallerySection.allCases, id: \.self) { section in
                Text(section.title).tag(section.rawValue)
            }
        }
        .pickerStyle(.segmented)
        // 크기는 `controlSize` 로 키운다.
        //
        // 한때 `frame(height:)` 로 키우려 했는데 **자리만 넓어지고 컨트롤은 그대로였다** —
        // 실제로 재 보면 트랙 높이가 배율과 상관없이 31.5pt 로 고정이었다.
        // 시스템 세그먼트는 제 높이를 스스로 정하고, 남는 자리에서는 가운데로 앉는다.
        // 그래서 아이패드에서도 아이폰과 같은 크기로 보였다.
        //
        // `controlSize` 는 애플이 내주는 손잡이고 손쉬운 사용 설정도 함께 따른다.
        // 못박은 높이를 쓰지 않으므로 기기가 바뀌어도 따라온다.
        .controlSize(scale > 1 ? .extraLarge : .regular)
        // 남은 자리는 위아래 여백으로 둔다. 컨트롤이 이보다 낮으면 가운데에 앉는다.
        .frame(height: Self.trackHeight * scale)
        .padding(.horizontal, Self.extraInset)
        // 넓은 화면에서 끝까지 늘어나지 않게 막는다.
        //
        // 갈래가 둘뿐인 컨트롤이 13인치 가로에서 1336 을 가로지르면
        // 「내가 그린」 라벨과 실제 누르는 자리가 멀어져 무엇을 누르는지 감이 오지 않는다.
        // 아래 선택 바가 같은 값을 쓰므로, 고르는 중에 둘이 함께 떠도 양 끝이 맞는다.
        // 아이폰(402 - 40 = 362)에서는 이 값에 닿지 않아 지금과 똑같다.
        .frame(maxWidth: DoodleLayout.controlMaxWidth)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    GallerySegmentedControl(selection: .constant(0))
        .padding(20)
        .background(Color.doodleBackground)
}
