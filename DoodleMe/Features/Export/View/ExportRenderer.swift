//
//  ExportRenderer.swift
//  DoodleMe
//

import SwiftUI

/// 카드를 그림 파일로 굽는다.
///
/// 카드 안쪽이 402x871 좌표계에 못박혀 있으므로 여기서는 **배율만** 정한다.
/// 판형이 바뀌어도 카드는 그대로 두고 이 바깥만 손대면 된다.
@MainActor
enum ExportRenderer {

    /// 굽는 배율. 어느 판이든 **가로를 정확히 1080** 으로 맞춘다.
    ///
    /// 세로(871)가 판형마다 같으므로 높이도 딱 떨어진다 —
    /// 9:16 은 1080x1920, 4:5 는 1080x1350, 1:1 은 1080x1080.
    ///
    /// 1080 은 인스타그램이 받는 가로다. 메타 「Sharing to Stories」 는
    /// 배경 이미지를 최소 720x1280, 9:16 또는 9:18 로 두라고 한다.
    static func scale(for ratio: ExportRatio) -> CGFloat {
        1080 / ExportCardLayout(ratio: ratio).size.width
    }

    /// 카드를 PNG 로 굽는다.
    ///
    /// 안에 `DoodleImageView` 같은 **늦게 채워지는 뷰**가 있으면 안 된다.
    /// 화면에 붙지 않은 뷰에서는 그 `task` 가 돌지 않아 빈 자리로 구워진다.
    /// 그림은 `DoodleImageCache` 가 이미 구워 둔 것을 쓴다.
    ///
    /// **판형은 여기서 직접 걸어 준다.**
    /// `ImageRenderer` 는 화면에 붙지 않은 뷰를 그리므로 미리보기 화면이 내린 환경값이
    /// 따라오지 않는다. 그대로 두면 어느 판을 골라도 9:16(기본값)으로 구워진다.
    static func png(_ card: some View, ratio: ExportRatio) -> Data? {
        let renderer = ImageRenderer(content: card.environment(\.exportRatio, ratio))
        renderer.scale = scale(for: ratio)
        // 종이 배경이 전부 채우므로 투명한 자리가 남을 일이 없다.
        renderer.isOpaque = true
        return renderer.uiImage?.pngData()
    }

    /// 구운 그림을 임시 파일로 내놓는다.
    ///
    /// 공유 시트에 `Image` 가 아니라 **파일 주소**를 건네는 이유가 있다.
    /// 인스타그램처럼 파일을 받아 가는 앱이 있고, 사진 앱에 저장할 때도
    /// 파일이면 원본 그대로 들어간다.
    static func temporaryFile(_ card: some View, ratio: ExportRatio, name: String) -> URL? {
        guard let data = png(card, ratio: ratio) else { return nil }
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
