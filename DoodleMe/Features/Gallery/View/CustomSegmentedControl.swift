//
//  CustomSegmentedControl.swift
//  DoodleMe
//

import SwiftUI

struct CustomSegmentedControl: View {
    @Binding var selection: Int
    let titles: [String]
    @Namespace private var segmentAnimation

    // Figma `iPhone 17 - 1` 기준 (트랙 347x34, 라운드 50)
    private static let height: CGFloat = 34
    private static let cornerRadius: CGFloat = 50

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<titles.count, id: \.self) { index in
                let isSelected = selection == index

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selection = index
                    }
                } label: {
                    Text(titles[index])
                        // 선택 여부로 크기·굵기를 바꾸지 않는다. 색으로만 구분한다.
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isSelected ? Color.doodleSegmentSelected : .doodleSegmentUnselected)
                        .frame(maxWidth: .infinity)
                        .frame(height: Self.height)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: Self.cornerRadius)
                                    .fill(.white.opacity(0.6))
                                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
                                    .matchedGeometryEffect(id: "segment", in: segmentAnimation)
                            }
                        }
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .fill(Color.doodleSegmentTrack)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        }
    }
}
