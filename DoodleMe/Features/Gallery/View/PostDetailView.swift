//
//  PostDetailView.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/11/26.
//

import Photos
import SwiftData
import SwiftUI

struct PostDetailView: View {
    let post: Post

    /// 내 그림을 공유할 때 보낼 이름. `GalleryPage`의 프로필 이름과 같은 저장소를 본다.
    @AppStorage("userName") private var userName = ""

    @State private var isFlipped = false
    @State private var showsQRCode = false
    @State private var showSaveAlert = false
    @State private var saveMessage = ""

    /// 내가 그린 글이면 내 이름을, 받은 글이면 보낸 사람 이름을 쓴다.
    private var shareSenderName: String {
        post.isMine ? userName : post.senderName
    }

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
                .accessibilityLabel("QR로 공유")

                Button {
                    Task { await saveDrawingToGallery() }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title2)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                }
                .accessibilityLabel("사진에 저장")
            }
            .glassEffect(.regular, in: .capsule)
            .padding(.bottom, 10)

            ZStack {
                // 앞면: 그림
                Image(.memoFront)
                    .resizable()
                    .frame(width: DoodleMetrics.canvasSize.width, height: DoodleMetrics.canvasSize.height)
                    .shadow(color: .black.opacity(0.25), radius: 10)
                    .overlay { drawingCanvas(lines: post.lines) }
                    .opacity(isFlipped ? 0 : 1)

                // 뒷면: 정보
                Image(.memoBack)
                    .resizable()
                    .scaleEffect(x: -1, y: 1)
                    .frame(width: DoodleMetrics.canvasSize.width, height: DoodleMetrics.canvasSize.height)
                    .shadow(color: .black.opacity(0.25), radius: 10)
                    .overlay {
                        if showsQRCode {
                            QRShareView(post: post, senderName: shareSenderName)
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
        }
        .padding()
        .alert("사진 저장", isPresented: $showSaveAlert) {
            Button("확인") { }
        } message: {
            Text(saveMessage)
        }
    }

    // MARK: - 뒷면

    @ViewBuilder
    private var backFaceContent: some View {
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
                        drawingCanvas(lines: post.senderProfileLines)
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                    }
                    Text(post.displaySenderName)
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal, 30)
                .padding(.top, 35)
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

    // MARK: - 그림 그리기

    private func drawingCanvas(lines: [Line]) -> some View {
        Canvas { context, size in
            let scale = size.width / DoodleMetrics.canvasSize.width
            context.transform = CGAffineTransform(scaleX: scale, y: scale)
            for line in lines {
                var path = Path()
                path.addLines(line.points)
                context.stroke(path, with: .color(.black), lineWidth: 2)
            }
        }
    }

    // MARK: - 사진 저장

    /// 사진 앱에 그림을 저장한다.
    ///
    /// 예전에는 `UIImageWriteToSavedPhotosAlbum` 의 결과 콜백을 모두 `nil` 로 버려서,
    /// 권한이 거부돼도 "저장 완료" 알럿이 떴다. 이제 권한과 저장 결과를 실제로 확인한다.
    private func saveDrawingToGallery() async {
        let renderer = ImageRenderer(content: drawingSnapshot)
        renderer.scale = 3

        guard let image = renderer.uiImage, let data = image.pngData() else {
            present("이미지를 만들지 못했어요.")
            return
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            present("사진 접근 권한이 없어 저장하지 못했어요. 설정에서 허용해주세요.")
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
            present("그림이 사진 앱에 저장됐어요.")
        } catch {
            present("저장에 실패했어요: \(error.localizedDescription)")
        }
    }

    /// 저장용 이미지. 화면에 보이는 카드가 아니라 흰 배경 위의 그림만 담는다.
    private var drawingSnapshot: some View {
        drawingCanvas(lines: post.lines)
            .frame(width: DoodleMetrics.canvasSize.width, height: DoodleMetrics.canvasSize.width)
            .background(.white)
    }

    private func present(_ message: String) {
        saveMessage = message
        showSaveAlert = true
    }
}

#Preview {
    PostDetailView(post: Post(lines: [], text: "테스트", isMine: false))
        .modelContainer(LocalDataStore.makePreviewContainer())
}
