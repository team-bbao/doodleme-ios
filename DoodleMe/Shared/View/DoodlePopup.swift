//
//  DoodlePopup.swift
//  DoodleMe
//

import SwiftUI

/// 앱 공통 팝업 껍데기.
///
/// 화면을 완전히 덮는 시스템 시트 대신, 배경을 어둡게 깔고 가운데에 카드를 띄운다.
/// 갤러리의 프로필 확인 팝업과 같은 결이다.
///
/// 껍데기(어두운 배경 · 카드 모양 · 등장 애니메이션)만 맡고 안쪽은 건드리지 않으므로,
/// 내용 뷰를 갈아끼우거나 `cardPadding` 같은 값만 바꿔 디자인을 잡을 수 있다.
///
/// 여닫을 때는 호출하는 쪽에서 `withAnimation` 으로 감싸야 전환이 붙는다.
struct DoodlePopup<Content: View>: View {

    /// 뒷배경을 얼마나 어둡게 덮을지.
    var dimOpacity: Double = 0.4
    /// 카드 안쪽 여백.
    var cardPadding: CGFloat = 24
    /// 카드 좌우로 남길 화면 여백.
    var horizontalInset: CGFloat = 32
    /// 카드 모서리 둥글기.
    var cornerRadius: CGFloat = 30
    /// 어두운 배경을 탭했을 때. `nil` 이면 배경 탭으로 닫히지 않는다.
    var onBackgroundTap: (() -> Void)?

    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(dimOpacity)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onBackgroundTap?() }

            content
                .padding(cardPadding)
                .background(.white, in: RoundedRectangle(cornerRadius: cornerRadius))
                .padding(.horizontal, horizontalInset)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }
}
