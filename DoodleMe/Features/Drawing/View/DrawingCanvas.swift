//
//  DrawingCanvas.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/10/26.
//

import SwiftUI

struct DrawingCanvas: View {

    let session: DrawingSession

    var body: some View {
        Canvas { context, _ in
            for line in session.lines {
                var path = Path()
                path.addLines(line.points)
                context.stroke(path, with: .color(.black), lineWidth: 3)
            }
        }
        .frame(width: DoodleMetrics.canvasSize.width, height: DoodleMetrics.canvasSize.height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { session.handleDrag(at: $0.location) }
                .onEnded { _ in session.endStroke() }
        )
    }
}
