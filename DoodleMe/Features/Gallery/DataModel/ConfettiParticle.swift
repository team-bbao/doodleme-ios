//
//  ConfettiParticle.swift
//  DoodleMe
//

import SwiftUI

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let angle: Double
    let distance: CGFloat
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let spin: Double
}
