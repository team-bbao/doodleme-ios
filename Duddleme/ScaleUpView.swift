//
//  ScaleUpView.swift
//  Duddleme
//
//  Created by Apple Developer Academy on 8/11/26.
//

import SwiftUI
import SwiftData
import CoreImage

struct ScaleUpView: View {
    let post: Post
    
    let gradientColors: [Color] = [
        .gradientTop,
        .gradientTop,
        .gradientBottom
    ]

    @State private var isFlipped = false
    @State private var showShareQR = false
    @State private var showSaveAlert = false
    @AppStorage("userName") private var userName = ""

    var body: some View {
        VStack(spacing: 24) {

            ZStack {
                // 앞면: 그림
              //  RoundedRectangle(cornerRadius: 20)
              //      .fill(.white)
                RoundedRectangle(cornerRadius: 30)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .frame(width: 350, height: 350)
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                    .overlay {
                        Canvas { context, size in
                            let scale = size.width / 350
                            context.transform = CGAffineTransform(scaleX: scale, y: scale)
                            for line in post.lines {
                                var path = Path()
                                path.addLines(line.points)
                                context.stroke(path, with: .color(.black), lineWidth: 2)
                            }
                        }
                    }
                    .opacity(isFlipped ? 0 : 1)

                // 뒷면: 정보
              //  Image("memo")
               //     .resizable()
                //    .frame(width: 350, height: 350)
                //    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                RoundedRectangle(cornerRadius: 30)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .frame(width: 350, height: 350)
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                    .overlay { backFaceContent }
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .animation(.easeInOut(duration: 0.5), value: isFlipped)
            .onTapGesture {
                isFlipped.toggle()
            }
            .shadow(color: .white.opacity(0.5), radius: 8)

            // by me: 공유하기 → QR 코드 sheet
            if post.isMine {
                Button {
                    showShareQR = true
                } label: {
                    Label("공유하기", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background {
                            Color.accent
                                .clipShape(.capsule)
                                .glassEffect(.regular, in: .capsule)
                                .opacity(0.7)
                        }
                        .foregroundStyle(.white)
                }
                .offset(y: 50)
                .shadow(color: .black.opacity(0.2), radius: 6)
            }

            // by others: 갤러리에 저장하기
            if !post.isMine {
                Button {
                    saveDrawingToGallery()
                } label: {
                    Label("갤러리에 저장하기", systemImage: "photo.badge.arrow.down")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background {
                            Color.accent
                                .clipShape(.capsule)
                                .glassEffect(.regular, in: .capsule)
                                .opacity(0.7)
                        }
                        .foregroundStyle(.white)
                }
                .offset(y: 50)
                .shadow(color: .black.opacity(0.2), radius: 6)
            }
        }
        .padding()
        .sheet(isPresented: $showShareQR) {
            QRShareView(post: post, senderName: userName)
        }
        .alert("저장 완료", isPresented: $showSaveAlert) {
            Button("확인") { }
        } message: {
            Text("그림이 갤러리에 저장됐어요.")
        }
    }

    @ViewBuilder
    var backFaceContent: some View {
        VStack(spacing: 0) {
            if post.isMine && !post.recipientName.isEmpty {
                HStack(spacing: 6) {
                    Text("To.")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.gray)
                    Text(post.recipientName)
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }

            if !post.isMine {
                HStack(spacing: 10) {
                    if post.senderProfileLines.isEmpty {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 28))
                            .foregroundStyle(.gray)
                    } else {
                        Canvas { context, size in
                            let scale = size.width / 350
                            context.transform = CGAffineTransform(scaleX: scale, y: scale)
                            for line in post.senderProfileLines {
                                var path = Path()
                                path.addLines(line.points)
                                context.stroke(path, with: .color(.black), lineWidth: 2)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                    }
                    Text(post.senderName.isEmpty ? "홍길동" : post.senderName)
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }

            Spacer()

            Text(post.text.isEmpty ? "(텍스트 없음)" : post.text)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.bottom, 35)

            Spacer()

            Text(post.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.gray)
                .padding(.bottom, 16)
        }
    }

    @MainActor
    func saveDrawingToGallery() {
        let lines = post.lines
        let drawingView = Canvas { context, size in
            let scale = size.width / 350
            context.transform = CGAffineTransform(scaleX: scale, y: scale)
            for line in lines {
                var path = Path()
                path.addLines(line.points)
                context.stroke(path, with: .color(.black), lineWidth: 2)
            }
        }
        .frame(width: 350, height: 350)
        .background(.white)

        let renderer = ImageRenderer(content: drawingView)
        renderer.scale = 3
        if let image = renderer.uiImage {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            showSaveAlert = true
        }
    }

    func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage else { return nil }
        let scale = 150.0 / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    ScaleUpView(post: Post(lines: [], text: "테스트", isMine: false))
        .modelContainer(for: Post.self, inMemory: true)
}
