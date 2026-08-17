//
//  ScaleUpView.swift
//  Duddleme
//
//  Created by Apple Developer Academy on 8/11/26.
//

import SwiftUI
import SwiftData

struct ScaleUpView: View {
    let post: Post

    let gradientColors: [Color] = [
        .gradientTop,
        .gradientTop,
        .gradientBottom
    ]

    @State private var isFlipped = false
    @State private var showSaveAlert = false
    @State private var showsQRCode = false

    var body: some View {
        VStack(spacing: 24) {

            HStack {
                Button {
                    showsQRCode = true
                    isFlipped = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                }

                Button {
                    saveDrawingToGallery()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title2)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                }
            }
            .glassEffect(.regular, in: .capsule)
            .padding(.bottom, 10)
            
            ZStack {
                // 앞면: 그림
                Image("메모지.body")
                    .resizable()
                    .frame(width: 350, height: 390)
                    .shadow(color: .black.opacity(0.25), radius: 10)
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
                Image("메모지.back")
                    .resizable()
                    .scaleEffect(x: -1, y: 1)
                    .frame(width: 350, height: 390)
                    .shadow(color: .black.opacity(0.25), radius: 10)
                    .overlay {
                        if showsQRCode {
                            QRShareView(post: post, senderName: post.senderName)
                                .onTapGesture {
                                    showsQRCode = false
                                }
                        } else {
                            backFaceContent
                        }
                    }
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            .padding(.bottom, 80)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .animation(.easeInOut(duration: 0.5), value: isFlipped)
            .onTapGesture {
                isFlipped.toggle()
            }
        //    .shadow(color: .white.opacity(0.5), radius: 8)

        }
        .padding()
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
                .padding(.horizontal, 30)
                .padding(.top, 35)
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
                .padding(.horizontal, 30)
                .padding(.top, 35)
            }

            Spacer()

            Text(post.text.isEmpty ? "(텍스트 없음)" : post.text)
                .font(.title2)
            //  .font(.system(size: 20))
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

}

#Preview {
    ScaleUpView(post: Post(lines: [], text: "테스트", isMine: false))
        .modelContainer(for: Post.self, inMemory: true)
}
