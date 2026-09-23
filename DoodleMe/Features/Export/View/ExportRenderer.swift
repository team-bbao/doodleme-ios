//
//  ExportRenderer.swift
//  DoodleMe
//

import SwiftUI

/// 카드를 그림 파일로 굽는다.
///
/// 카드 안쪽이 402x844 좌표계에 못박혀 있으므로 여기서는 **배율만** 정한다.
@MainActor
enum ExportRenderer {

    /// 굽는 배율. **가로를 정확히 1080** 으로 맞춘다. 1080 은 인스타그램이 받는 가로다.
    ///
    /// 카드가 390x844 이므로 구운 그림은 1080x2338 이 된다 —
    /// 844 x 2.7692 = 2337.23 이라 마지막 한 줄이 올림으로 붙는다.
    static let scale: CGFloat = 1080 / ExportCardLayout.size.width

    /// 카드를 PNG 로 굽는다.
    ///
    /// 안에 `DoodleImageView` 같은 **늦게 채워지는 뷰**가 있으면 안 된다.
    /// 화면에 붙지 않은 뷰에서는 그 `task` 가 돌지 않아 빈 자리로 구워진다.
    /// 그림은 `DoodleImageCache` 가 이미 구워 둔 것을 쓴다.
    ///
    static func png(_ card: some View) -> Data? {
        let renderer = ImageRenderer(content: card)
        renderer.scale = scale
        // 종이 배경이 전부 채우므로 투명한 자리가 남을 일이 없다.
        renderer.isOpaque = true
        return renderer.uiImage?.pngData()
    }

    /// 구운 그림을 임시 파일로 내놓는다.
    ///
    /// 공유 시트에 `Image` 가 아니라 **파일 주소**를 건네는 이유가 있다.
    /// 인스타그램처럼 파일을 받아 가는 앱이 있고, 사진 앱에 저장할 때도
    /// 파일이면 원본 그대로 들어간다.
    static func temporaryFile(_ card: some View, name: String) -> URL? {
        guard let data = png(card) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name).png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
