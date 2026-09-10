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

    /// Figma `222:1199` 의 높이. 시스템 기본값보다 조금 높다.
    private static let trackHeight: CGFloat = 35

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
        .frame(height: Self.trackHeight)
        .padding(.horizontal, Self.extraInset)
    }
}

#Preview {
    GallerySegmentedControl(selection: .constant(0))
        .padding(20)
        .background(Color.doodleBackground)
}
