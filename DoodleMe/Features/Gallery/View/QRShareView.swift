//
//  QRShareView.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/12/26.
//

import SwiftUI
import SwiftData
import CoreImage

struct QRShareView: View {
    let post: Post
    let senderName: String
    @Query private var allPosts: [Post]

    private var profilePost: Post? { allPosts.first(where: { $0.isProfile }) }

    private var qrContent: String? {
        guard let json = PostTransferData.encode(
            post: post,
            profilePost: profilePost,
            senderName: senderName.isEmpty ? nil : senderName
        ) else { return nil }
        guard let jsonData = json.data(using: .utf8) else { return nil }
        // base64url 인코딩 (URL 안전 문자로 변환)
        let base64url = jsonData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "duddleme://import?data=\(base64url)"
    }

    private var qrImage: UIImage? {
        guard let content = qrContent else { return nil }
        return generateQRCode(from: content)
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

    private func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage else { return nil }
        let scale = 520.0 / outputImage.extent.width
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
