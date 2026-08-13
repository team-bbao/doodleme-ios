//
//  GalleryItemView.swift
//  Duddleme
//
//  Created by Jaesung Lee on 8/13/26.
//

import SwiftUI

struct GalleryItemView: View {
    let post: Post
    
    private let gradientColors: [Color] = [
        .gradientTop,
        .gradientTop,
        .gradientBottom
    ]
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            )
            .frame(height: 170)
            .overlay {
                GeometryReader { content in
                    Canvas { context, size in
                        let scaleX = content.size.width / 350
                        let scaleY = content.size.height / 350
                        context.transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
                        for line in post.lines {
                            var path = Path()
                            path.addLines(line.points)
                            context.stroke(path, with: .color(.black), lineWidth: 2)
                        }
                    }
                }
            }
    }
}

#Preview {
    GalleryItemView(
        post: Post(
            lines: [],
            text: "text",
            isMine: true
        )
    )
}
