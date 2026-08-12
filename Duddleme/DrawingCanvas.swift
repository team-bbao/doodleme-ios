//
//  DrawingCanvas.swift
//  Duddleme
//
//  Created by Apple Developer Academy on 8/10/26.
//

import SwiftUI

struct DrawingCanvas: View {
    
    @Binding var selectedTab: Int
    @Binding var lines: [Line]
    @Binding var redoStack: [[Line]]
    @Binding var undoStack: [[Line]]
    @Binding var hasSavedSnapshot: Bool
    
    
    var body: some View {
        
        
        Canvas { context, size in
            for line in lines {
                var path = Path()
                path.addLines(line.points)
                context.stroke(path, with: .color(.black), lineWidth: 3)
            }
        }
        .frame(width: 350, height: 390)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let newPoint = value.location
                    //지우기
                 
                    
                    if selectedTab == 1 {
                        //지우개: 지우기 전 개수를 기억
                        let countBefore = lines.count
                        let beforeState = lines
                        lines.removeAll() { line in
                            line.points.contains { point in distance(point, newPoint) < 5 }
                        }
                        if lines.count < countBefore && !hasSavedSnapshot {
                            undoStack.append(beforeState)
                            redoStack.removeAll()
                            hasSavedSnapshot = true
                        }
                        
                    } else if selectedTab == 0 {
                        //기존 연필그리기 로직
                        if !hasSavedSnapshot {
                            undoStack.append(lines)
                            redoStack.removeAll()
                            hasSavedSnapshot = true
                        }
                        
                        if lines.isEmpty {
                            lines.append(Line(points: [newPoint]))
                        } else {
                            lines[lines.count - 1].points.append(newPoint)
                        }
                    }
                    
                }
            //손가락을 화면에서 뗀 순간 발생하는 로직
                .onEnded { _ in
                    lines.append(Line())
                    hasSavedSnapshot = false
                }
        )
        
        
    }
    
    func distance(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx*dx + dy*dy)
    }
}
