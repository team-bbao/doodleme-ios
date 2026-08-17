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
            image = PKDrawing(doodleData: drawingData).canvasImage()
        }
        .accessibilityHidden(true)
    }
}
