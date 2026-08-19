//
//  Duration+Seconds.swift
//  DoodleMe
//

import Foundation

extension Duration {
    /// 초 단위 `Double`로 환산한다. `ContinuousClock`으로 잰 경과 시간을 다룰 때 쓴다.
    var seconds: Double {
        let (wholeSeconds, attoseconds) = components
        return Double(wholeSeconds) + Double(attoseconds) * 1e-18
    }
}
