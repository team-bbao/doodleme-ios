//
//  GallerySegmentedControl.swift
//  DoodleMe
//

import SwiftUI

/// 「너가 그린 / 내가 그린」을 고르는 막대. Figma `iPhone 17 - 12` 의 `Frame 2`(85:530) 기준.
///
/// 시스템 `Picker(.segmented)` 를 쓰지 않는다.
/// 흰 트랙에 얹힌 회색 캡슐과 14pt 라벨은 시스템 세그먼트로는 만들 수 없고,
/// 이 막대는 종이 위에 놓인 카드처럼 보여야 화면의 다른 요소와 결이 맞는다.
///
/// 칸의 **순서와 뜻**은 `GallerySection` 이 정한다.
/// 디자인 파일은 「내가 그린」을 왼쪽에 두지만, 저장된 값의 의미가 뒤집히므로 코드 순서를 따른다.
struct GallerySegmentedControl: View {

    @Binding var selection: Int

    @Namespace private var chipAnimation

    // Figma `Frame 2`(85:530) 치수. 트랙 362x39 안에 173x31 캡슐 둘.
    /// 트랙 높이.
    private static let trackHeight: CGFloat = 39
    /// 캡슐 높이. 트랙 안쪽으로 위아래 4 씩 들어간다.
    private static let chipHeight: CGFloat = 31
    /// 트랙과 캡슐 사이 여백.
    private static let inset: CGFloat = 4
    /// 캡슐 둘 사이 간격.
    private static let chipSpacing: CGFloat = 7
    /// 트랙·캡슐 모서리. 값이 높이보다 커서 사실상 알약이 된다.
    private static let cornerRadius: CGFloat = 50

    var body: some View {
        HStack(spacing: Self.chipSpacing) {
            ForEach(GallerySection.allCases, id: \.self) { section in
                chip(for: section)
            }
        }
        .padding(Self.inset)
        .frame(height: Self.trackHeight)
        .background {
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .fill(.white)
                // Figma: 0 4 15 / 검정 5%. SwiftUI 반경은 blur 의 절반.
                .shadow(color: .black.opacity(0.05), radius: 7.5, y: 4)
        }
    }

    @ViewBuilder
    private func chip(for section: GallerySection) -> some View {
        let isSelected = selection == section.rawValue

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selection = section.rawValue
            }
        } label: {
            Text(section.title)
                // Figma: 선택 Medium / 비선택 Regular, 둘 다 14.
                .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? Color.doodleSegmentLabel : Color.doodleSubtext)
                .frame(maxWidth: .infinity)
                .frame(height: Self.chipHeight)
                .background {
                    if isSelected {
                        // 고른 칸이 바뀔 때 캡슐이 미끄러져 옮겨간다.
                        Capsule()
                            .fill(Color.doodleSegmentChip)
                            .matchedGeometryEffect(id: "chip", in: chipAnimation)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    GallerySegmentedControl(selection: .constant(0))
        .padding(20)
        .background(Color.doodleBackground)
}
