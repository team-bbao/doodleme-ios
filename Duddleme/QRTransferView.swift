//
//  QRTransferView.swift
//  Duddleme
//
//  Created by Apple Developer Academy on 8/12/26.
//

import SwiftUI
import SwiftData
import AVFoundation
import CoreImage

// MARK: - Transfer Data Model

struct PostTransferData: Codable {
    var d: [[Int]]   // drawing lines: [x1,y1,x2,y2,...]
    var t: String    // text
    var dt: Double   // date (unix timestamp)
    var p: [[Int]]?  // profile drawing lines
    var n: String?   // sender name

    // Post → JSON 문자열
    static func encode(post: Post, profilePost: Post?, senderName: String?) -> String? {
        let drawingLines = post.lines.map { line in
            stride(from: 0, to: line.points.count, by: 3).map { line.points[$0] }
                .flatMap { [Int($0.x.rounded()), Int($0.y.rounded())] }
        }
        let profileLines = profilePost?.lines.map { line in
            stride(from: 0, to: line.points.count, by: 3).map { line.points[$0] }
                .flatMap { [Int($0.x.rounded()), Int($0.y.rounded())] }
        }
        let data = PostTransferData(
            d: drawingLines,
            t: post.text,
            dt: post.createdAt.timeIntervalSince1970,
            p: profileLines,
            n: senderName.flatMap { $0.isEmpty ? nil : $0 }
        )
        guard let jsonData = try? JSONEncoder().encode(data) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }

    // JSON 문자열 → PostTransferData
    static func decode(from string: String) -> PostTransferData? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PostTransferData.self, from: data)
    }

    // flat int 배열 → [Line]
    private func toLines(_ arrays: [[Int]]) -> [Line] {
        arrays.map { flat in
            var line = Line()
            stride(from: 0, to: flat.count - 1, by: 2).forEach { i in
                line.points.append(CGPoint(x: flat[i], y: flat[i + 1]))
            }
            return line
        }
    }

    func makeDrawingLines() -> [Line] { toLines(d) }
    func makeProfileLines() -> [Line]? { p.map { toLines($0) } }
}

// MARK: - QR Share View

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

// MARK: - QR Scanner View

struct QRScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPosts: [Post]

    @State private var scanned: PostTransferData? = nil
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                CameraPreviewView { result in
                    guard scanned == nil else { return }
                    scanned = PostTransferData.decode(from: result)
                }
                .ignoresSafeArea()

                // 스캔 가이드 프레임
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.8), lineWidth: 3)
                    .frame(width: 260, height: 260)

                VStack {
                    Spacer()

                    if let data = scanned {
                        scannedPreview(data: data)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 50)
                    } else {
                        Text("QR 코드를 네모 안에 비춰주세요")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.black.opacity(0.55))
                            .clipShape(Capsule())
                            .padding(.bottom, 50)
                    }
                }
            }
            .navigationTitle("QR 스캔")
            .navigationBarTitleDisplayMode(.inline)
            .alert("저장 완료", isPresented: $showAlert) {
                Button("확인") { scanned = nil }
            } message: {
                Text(alertMessage)
            }
        }
    }

    @ViewBuilder
    func scannedPreview(data: PostTransferData) -> some View {
        VStack(spacing: 14) {
            Text("QR 인식됨")
                .font(.headline)
                .foregroundStyle(.white)

            if let name = data.n, !name.isEmpty {
                Text("From. \(name)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }

            Text(data.t.isEmpty ? "(텍스트 없음)" : "\"\(data.t)\"")
                .font(.body)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            HStack(spacing: 12) {
                Button("다시 스캔") {
                    scanned = nil
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.white.opacity(0.2))
                .clipShape(Capsule())

                Button("저장하기") {
                    importPost(data: data)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.white)
                .clipShape(Capsule())
            }
        }
        .padding(20)
        .background(.black.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    func importPost(data: PostTransferData) {
        let newPost = Post(lines: data.makeDrawingLines(), text: data.t, isMine: false)
        newPost.createdAt = Date(timeIntervalSince1970: data.dt)
        newPost.senderName = data.n ?? "홍길동"
        newPost.senderProfileLines = data.makeProfileLines() ?? []
        modelContext.insert(newPost)

        alertMessage = "By others에 그림이 저장됐어요."
        showAlert = true
    }
}

// MARK: - Camera Preview (AVFoundation)

struct CameraPreviewView: UIViewRepresentable {
    let onScan: (String) -> Void

    func makeUIView(context: Context) -> CameraUIView {
        let view = CameraUIView()
        view.onScan = onScan
        view.setupSession()
        return view
    }

    func updateUIView(_ uiView: CameraUIView, context: Context) {}

    class CameraUIView: UIView, AVCaptureMetadataOutputObjectsDelegate {
        var onScan: ((String) -> Void)?
        private var session: AVCaptureSession?

        func setupSession() {
            let session = AVCaptureSession()
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(previewLayer)

            self.session = session
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            layer.sublayers?.forEach { $0.frame = bounds }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput objects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let obj = objects.first as? AVMetadataMachineReadableCodeObject,
                  let value = obj.stringValue else { return }
            onScan?(value)
        }
    }
}

#Preview {
    QRScannerView()
        .modelContainer(for: Post.self, inMemory: true)
}
