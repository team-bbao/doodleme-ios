//
//  ExportRenderer.swift
//  DoodleMe
//

import SwiftUI

/// 카드를 그림 파일로 굽는다.
///
/// 카드가 402x871 좌표계에 못박혀 있으므로 여기서는 **배율만** 정한다.
/// 나중에 인스타 규격(1080x1920)으로 옮길 때도 카드는 그대로 두고 이 바깥만 손대면 된다.
@MainActor
enum ExportRenderer {

    /// 굽는 배율. 카드(9:16)를 **정확히 1080x1920** 으로 만든다.
    ///
    /// 인스타그램 스토리 규격이자 메타가 공식 문서에서 권하는 비율이다 —
    /// 「Sharing to Stories」 는 배경 이미지를 최소 720x1280, 9:16 또는 9:18 로 두라고 한다.
    /// 피드(4:5)로 올릴 때는 인스타그램이 알아서 자르므로 한 벌만 굽는다.
    static let scale: CGFloat = 1080 / ExportCardLayout.size.width

    /// 카드를 PNG 로 굽는다.
    ///
    /// 안에 `DoodleImageView` 같은 **늦게 채워지는 뷰**가 있으면 안 된다.
    /// 화면에 붙지 않은 뷰에서는 그 `task` 가 돌지 않아 빈 자리로 구워진다.
    /// 그림은 `DoodleImageCache` 가 이미 구워 둔 것을 쓴다.
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
