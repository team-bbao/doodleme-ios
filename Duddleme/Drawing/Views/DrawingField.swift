//
//  DrawingField.swift
//  Duddleme
//
//  Created by Jaesung Lee on 8/13/26.
//

import SwiftUI
import PencilKit

struct DrawingField: UIViewRepresentable {
    @Bindable var paint: Paint
    @Binding var canvasView: PKCanvasView
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.delegate = context.coordinator
        canvasView.drawingPolicy = .anyInput
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.tool = paint.currentTool
        if paint.drawing != uiView.drawing {
            uiView.drawing = paint.drawing
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $paint.drawing)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var drawing: Binding<PKDrawing>
        
        init(drawing: Binding<PKDrawing>) {
            self.drawing = drawing
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing.wrappedValue = canvasView.drawing
        }
    }
}

#Preview {
    @Previewable @State var paint = Paint()
    @Previewable @State var canvasView = PKCanvasView()
    
    DrawingField(paint: paint, canvasView: $canvasView)
}
