//
//  ConfettiBurst.swift
//  DoodleMe
//

import SwiftUI

struct ConfettiBurst: View {
    let trigger: Int

    @State private var particles: [ConfettiParticle] = []
    @State private var progress: CGFloat = 0

    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(particle.color)
                    .frame(width: particle.width, height: particle.height)
                    .rotationEffect(.degrees(particle.spin * Double(progress)))
                    .offset(
                        x: CGFloat(cos(particle.angle)) * CGFloat((60 + particle.distance * progress)),
                        y: CGFloat(sin(particle.angle)) * CGFloat((60 + particle.distance * progress))
                    )
                    .opacity(Double(1 - progress))
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            particles = (0..<24).map { index in
                ConfettiParticle(
                    angle: Double(index) / 24 * 2 * .pi + .random(in: -0.2...0.2),
                    distance: .random(in: 50...110),
                    color: colors.randomElement() ?? .yellow,
                    width: .random(in: 4...7),
                    height: .random(in: 7...12),
                    spin: .random(in: -540...540)
                )
            }
            progress = 0
            withAnimation(.easeOut(duration: 0.9)) {
                progress = 1
            }
        }
    }
}
