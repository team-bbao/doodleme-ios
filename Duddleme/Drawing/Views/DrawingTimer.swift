//
//  DrawingTimer.swift
//  Duddleme
//
//  Created by Jaesung Lee on 8/13/26.
//

import Combine
import SwiftUI

struct DrawingTimer: View {
    // MARK: - 타이머
    /// 시작여부
    @Binding var isStarted: Bool
    /// 남은 시간
    @State private var timeRemaining: Double = 30
    /// 0.05초 마다 퍼블리싱 하는 타이머
    private let timer = Timer
        .publish(every: 0.05, on: .main, in: .common)
        .autoconnect()
    
    var body: some View {
        Slider(value: $timeRemaining, in: 0...30)
            .onReceive(timer) { _ in
                if isStarted, timeRemaining > 0
                {
                    timeRemaining -= 0.05
                }
            }
            .sliderThumbVisibility(.hidden)
            .allowsHitTesting(false) // 사용자가 멋대로 조작하지 못하도록
    }
}

#Preview {
    DrawingTimer(isStarted: .constant(true))
}
