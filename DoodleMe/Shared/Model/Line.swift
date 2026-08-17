//
//  Line.swift
//  DoodleMe
//

import CoreGraphics
import Foundation

/// 손그림의 한 획(stroke). 사용자가 화면에 손을 대고 뗄 때까지 찍힌 점들의 모음.
struct Line: Codable {
    var points: [CGPoint] = []
}
