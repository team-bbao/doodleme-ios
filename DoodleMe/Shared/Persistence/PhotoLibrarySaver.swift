//
//  PhotoLibrarySaver.swift
//  DoodleMe
//

import Photos
import UIKit

/// 그림을 사진 앱에 저장한다.
///
/// 상세 화면(한 장)과 갤러리의 고르기(여러 장)가 같은 자리를 쓴다.
/// 예전에는 상세 화면 안에만 있어서, 갤러리에서 여러 장을 저장하려면 같은 코드를 한 벌 더
/// 두어야 했다 — 권한을 묻는 방식이나 실패했을 때 하는 말이 두 곳에서 갈릴 자리였다.
enum PhotoLibrarySaver {

    /// 저장을 마치고 사람에게 할 말.
    enum Outcome {
        /// 고른 것이 모두 들어갔다.
        case saved(count: Int)
        /// 일부만 들어갔다. 조용히 넘어가지 않는다.
        case partial(saved: Int, total: Int)
        case noPermission
        case failed(String)

        /// 확인창에 띄울 문구.
        var message: String {
            switch self {
            case .saved(let count):
                count == 1 ? "그림이 사진 앱에 저장됐어요." : "\(count)장이 사진 앱에 저장됐어요."
            case .partial(let saved, let total):
                "\(total)장 중 \(saved)장만 저장됐어요."
            case .noPermission:
                "사진 접근 권한이 없어 저장하지 못했어요. 설정에서 허용해주세요."
            case .failed(let reason):
                "저장에 실패했어요: \(reason)"
            }
        }
    }

    /// 그림들을 사진 앱에 넣는다.
    ///
    /// **권한은 맨 앞에서 한 번만 묻는다.** 장마다 물으면 열 장을 고른 사람에게
    /// 같은 질문이 열 번 간다.
    ///
    /// 한 장이 실패해도 멈추지 않고 나머지를 마저 넣는다.
    /// 열 장 중 아홉 장이 들어갈 수 있는데 첫 장에서 그만두면 아홉 장을 잃는다.
    @MainActor
    static func save(_ drawings: [Data]) async -> Outcome {
        guard !drawings.isEmpty else { return .saved(count: 0) }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return .noPermission }

        var saved = 0
        var firstError: String?

        for drawing in drawings {
            guard let data = snapshot(of: drawing) else {
                firstError = firstError ?? "이미지를 만들지 못했어요."
                continue
            }
            do {
                try await write(data)
                saved += 1
            } catch {
                firstError = firstError ?? error.localizedDescription
            }
        }

        if saved == drawings.count { return .saved(count: saved) }
        if saved > 0 { return .partial(saved: saved, total: drawings.count) }
        return .failed(firstError ?? "알 수 없는 까닭")
    }

    /// 사진 앱에 남길 이미지. 흰 바탕(`#FFFFFF`)에 획만 담는다.
    ///
    /// 화면의 메모지에는 그늘과 접힌 모서리가 있지만 사진에는 넣지 않는다.
    /// 사진첩에 남는 건 그림이지 종이가 아니다.
    ///
    /// SwiftUI `ImageRenderer` 로 `DoodleImageView` 를 굽지 않는다.
    /// 그 뷰는 `.task` 로 그림을 늦게 채우는데, 화면에 붙지 않은 뷰에서는 그 `task` 가 돌지 않는다.
    /// 그대로 구우면 획 없는 흰 종이만 저장된다.
    /// 캐시가 이미 구워 둔 그림이 있으니 흰 바탕에 얹기만 하면 된다.
    ///
    /// 캔버스 비율을 그대로 써야 그린 대로 저장된다.
    @MainActor
    static func snapshot(of drawingData: Data) -> Data? {
        let drawing = DoodleImageCache.image(for: drawingData)
        let canvas = CGRect(origin: .zero, size: DoodleMetrics.canvasSize)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        // 사진에 투명한 자리를 남기지 않는다. 흰 바탕이 전부 채운다.
        format.opaque = true

        let image = UIGraphicsImageRenderer(size: canvas.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(canvas)
            drawing.draw(in: canvas)
        }
        return image.pngData()
    }

    /// 사진 앱에 실제로 쓰는 부분.
    ///
    /// 화면 밖으로 꺼내 격리를 끊어야 한다.
    /// `View` 안에 두면 메인 액터에 묶이고 넘기는 클로저도 함께 묶이는데,
    /// `performChanges` 는 PhotoKit 이 **자기 큐**에서 그 클로저를 부른다.
    /// 그러면 Swift 6 이 "여기는 메인이 아니다" 하고 앱을 끊는다 —
    /// 저장 버튼을 누를 때마다 `EXC_BREAKPOINT` 로 튕기던 것이 이것이었다.
    nonisolated private static func write(_ data: Data) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
        }
    }
}
