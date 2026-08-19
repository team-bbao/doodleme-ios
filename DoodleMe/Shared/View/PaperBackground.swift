//
//  PaperBackground.swift
//  DoodleMe
//

import SwiftUI

/// 화면 전체를 덮는 종이 질감 배경.
///
/// 예전에는 화면마다 `GeometryReader` 로 폭만 맞춰 깔았다.
/// 그러면 `GeometryReader` 가 안전영역 **안쪽** 크기를 받기 때문에
/// 그 크기로 잰 그림이 화면 아래 안전영역까지 닿지 못하고 흰 띠가 남는다.
/// 바깥 컨테이너가 안전영역을 무시하는 화면에서는 가려져 보이지 않았지만,
/// 그렇지 않은 화면(공유 화면)에서는 그대로 드러났다.
///
/// 여기서는 `GeometryReader` 자체를 안전영역 밖까지 넓히고
/// 폭과 높이를 모두 못박아 어느 화면에 깔아도 빈틈이 없게 한다.
struct PaperBackground: View {
    var body: some View {
        GeometryReader { proxy in
            Image(.papertype1)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
