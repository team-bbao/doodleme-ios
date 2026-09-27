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

    /// 카드를 PNG 로 굽는다.
    ///
    /// 안에 `DoodleImageView` 같은 **늦게 채워지는 뷰**가 있으면 안 된다.
    /// 화면에 붙지 않은 뷰에서는 그 `task` 가 돌지 않아 빈 자리로 구워진다.
    /// 그림은 `DoodleImageCache` 가 이미 구워 둔 것을 쓴다.
    ///
    /// **가로는 폭이 얼마든 정확히 1080 으로 나온다.** 1080 은 인스타그램이 받는 가로라
    /// 배율을 고정하지 않고 폭에 맞춰 되잡는다. 도안 칸(390)이면 1080x2338 이,
    /// 스토리 폭(474.75)이면 1080x1920 이 된다.
    ///
    /// - Parameter width: 카드를 얼마나 넓게 그릴지. 기본은 도안 칸이고,
    ///   인스타그램 스토리로 보낼 때만 `ExportCardLayout.storyWidth` 를 넘긴다.
    static func png(_ card: some View, width: CGFloat = ExportCardLayout.size.width) -> Data? {
        let renderer = ImageRenderer(content: card.environment(\.exportCardWidth, width))
        renderer.scale = 1080 / width
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

extension EnvironmentValues {
    /// 카드를 얼마나 넓게 그릴지. `ExportCard` 가 읽는다.
    ///
    /// **굽는 쪽에서 직접 걸어 준다.** `ImageRenderer` 는 화면에 붙지 않은 뷰를 그리므로
    /// 미리보기 화면이 내린 환경값이 따라오지 않는다.
    @Entry var exportCardWidth: CGFloat = ExportCardLayout.size.width
}
