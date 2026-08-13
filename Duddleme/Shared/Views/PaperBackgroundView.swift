//
//  PaperBackgroundView.swift
//  Duddleme
//
//  Created by Jaesung Lee on 8/13/26.
//

import SwiftUI

struct PaperBackgroundView: View {
    var body: some View {
        GeometryReader { proxy in
            Image("papertype1")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: proxy.size.width)
                .clipped()
                .ignoresSafeArea()
        }
    }
}

#Preview {
    PaperBackgroundView()
}
