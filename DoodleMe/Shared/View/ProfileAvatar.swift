//
//  ProfileAvatar.swift
//  DoodleMe
//

import SwiftUI

/// 프로필 그림이 담긴 흰 원.
///
/// 갤러리 머리말이 혼자 쓰던 것을 빼냈다. 사이드바(신원 덩이)와 접었을 때의 버튼 줄이
/// 같은 얼굴을 보여 줘야 해서, 그릴 줄 아는 곳을 한 군데로 모은다.
/// 연필 뱃지는 여기 없다 — 그것은 「고칠 수 있다」는 표시라 자리마다 뜻이 달라진다.
struct ProfileAvatar: View {
    /// 프로필로 앉힌 그림. 없으면 기본 낙서가 대신 선다.
    let drawingData: Data?
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle().foregroundStyle(.white)

            if let drawingData {
                DoodleImageView(drawingData: drawingData, contentMode: .fill)
            } else {
                // 원을 꽉 채우지 않고 지름의 80% 크기로 가운데 놓는다.
                DefaultDoodleImage()
                    .frame(width: diameter * 0.8, height: diameter * 0.8)
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
    }
}
