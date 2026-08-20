//
//  PeerAvatarPalette.swift
//  DoodleMe
//

import SwiftUI

/// 주변에서 찾은 사람에게 붙여줄 기본 프로필 그림.
///
/// 발견 단계에서는 상대의 실제 프로필을 알 수 없다.
/// (프로필은 그림을 보낼 때 함께 전달되고, 광고 정보에 실어 보내기엔 용량 제한이 빡빡하다.)
/// 그래서 미리 준비한 기본 그림 중 하나를 골라 붙인다.
enum PeerAvatarPalette {

    /// Figma `iPhone 17 - 4` 의 낙서 3개와 `iPhone 17 - 7` 의 2개를 벡터로 내보낸 것.
    /// 더 늘리려면 에셋을 넣고 여기에 한 줄 추가하면 된다.
    static let images: [ImageResource] = [
        .peerAvatar1,
        .peerAvatar2,
        .peerAvatar3,
        .peerAvatar4,
        .peerAvatar5
    ]

    /// 이름을 기준으로 고른다.
    ///
    /// 매번 무작위로 뽑으면 화면이 다시 그려질 때마다 얼굴이 바뀐다.
    /// 이름을 해시해서 고르면 무작위로 흩어지면서도 같은 사람에게는 늘 같은 얼굴이 붙는다.
    static func image(for peerName: String) -> ImageResource {
        guard !images.isEmpty else { return .profileDefault }
        let hash = peerName.unicodeScalars.reduce(into: UInt64(5381)) { result, scalar in
            result = result &* 33 &+ UInt64(scalar.value)
        }
        return images[Int(hash % UInt64(images.count))]
    }
}
