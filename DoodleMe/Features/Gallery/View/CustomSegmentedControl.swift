//
//  CustomSegmentedControl.swift
//  DoodleMe
//

import SwiftUI

struct CustomSegmentedControl: View {
    @Binding var selection: Int
    let titles: [String]
    @Namespace private var segmentAnimation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<titles.count, id: \.self) { index in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selection = index
                    }
                } label: {
                    Text(titles[index])
                        .font(selection == index
                              ? .system(size: 16, weight: .semibold, design: .rounded)
                              : .system(size: 14, weight: .regular))
                        .foregroundColor(selection == index ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 35)
                        .background {
                            if selection == index {
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(.white)
                                    .shadow(color: .black.opacity(0.12), radius: 8)
                                    .matchedGeometryEffect(id: "segment", in: segmentAnimation)
                            }
                        }
                }
            }
        }
        .background(Color(red: 0.97, green: 0.98, blue: 0.98), in: RoundedRectangle(cornerRadius: 29))
        
    }
}
