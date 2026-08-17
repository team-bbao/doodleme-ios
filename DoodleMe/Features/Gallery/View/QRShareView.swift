//
//  QRShareView.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/12/26.
//

import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

struct QRShareView: View {
    let post: Post
    let senderName: String

    @Query(filter: #Predicate<Post> { $0.isProfile }) private var profilePosts: [Post]

    private var qrImage: UIImage? {
        guard let url = PostTransferData.makeShareURL(
            post: post,
            profilePost: profilePosts.first,
            senderName: senderName.isEmpty ? nil : senderName
        ) else { return nil }
        return makeQRCode(from: url.absoluteString)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("공유하기")
                .font(.headline)
                .padding(.top, 24)

            if let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 260, height: 260)
                    .accessibilityLabel("공유용 QR 코드")

                Text("스캔하여 전달 받으세요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(.red.opacity(0.7))
                    .padding(.top, 20)

                Text("QR 생성 실패\n그림이 너무 복잡해요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .presentationDetents([.medium])
    }

    /// 문자열 키(`setValue(_:forKey:)`) 대신 타입 안전한 빌트인 필터를 쓴다.
    private func makeQRCode(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scale = 520 / outputImage.extent.width
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
