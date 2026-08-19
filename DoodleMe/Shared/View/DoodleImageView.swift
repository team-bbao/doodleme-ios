//
//  DoodleImageView.swift
//  DoodleMe
//

import PencilKit
import SwiftUI

/// 저장된 그림을 보여준다. 그리드·상세·프로필이 모두 이 뷰를 쓴다.
///
/// `PKDrawing` 을 이미지로 굽는 비용이 있어 `drawingData` 가 바뀔 때만 다시 렌더링한다.
struct DoodleImageView: View {
    let drawingData: Data
    var contentMode: ContentMode = .fit

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Color.clear
            }
        }
        .task(id: drawingData) {
            image = DoodleImageCache.image(for: drawingData)
        }
        .accessibilityHidden(true)
    }
}

/// 한 번 구운 그림을 들고 있다가 다시 쓴다.
///
/// 굽는 비용이 만만치 않다. 350x390 캔버스를 3배로 그리면 백만 픽셀이 넘는다.
/// 그런데 같은 그림이 그리드·상세·프로필·카드 뒷면 아바타에 동시에 나오고,
/// 그리드를 스크롤하면 화면 밖으로 나갔던 카드가 다시 들어오면서 뷰가 새로 만들어진다.
/// 그때마다 처음부터 구우면 스크롤이 걸린다.
///
/// `NSCache` 라서 메모리가 부족해지면 시스템이 알아서 비운다. 우리가 챙길 일이 없다.
@MainActor
enum DoodleImageCache {

    /// 들고 있을 장수. 그리드 한 화면에 여덟 장 남짓이라 스크롤 앞뒤로 넉넉하다.
    private static let limit = 60

    private static let cache: NSCache<NSData, UIImage> = {
        let cache = NSCache<NSData, UIImage>()
        cache.countLimit = limit
        return cache
    }()

    static func image(for data: Data) -> UIImage {
        let key = data as NSData
        if let cached = cache.object(forKey: key) { return cached }

        let rendered = PKDrawing(doodleData: data).canvasImage()
        cache.setObject(rendered, forKey: key)
        return rendered
    }
}
