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

    /// 내가 그린 카드의 아바타로 쓸 내 프로필 그림.
    @Query(filter: #Predicate<Post> { $0.isProfile }) private var profilePosts: [Post]

    @State private var isFlipped = false
    /// 앞면에 접힌 모서리를 보여줄 차례인지.
    @State private var showFold = false

    /// 접힘을 보여줬다 감추는 주기. 한 상태가 이만큼 머문다.
    private static let foldInterval: Duration = .milliseconds(1250)
    /// 두 상태를 오갈 때 걸리는 시간. 주기에 비해 길면 계속 움직이는 느낌이 든다.
    private static let foldFade: TimeInterval = 0.35
    @State private var showSharingScreen = false
    @State private var showSaveAlert = false
    @State private var saveMessage = ""

    /// 내가 그린 글이면 내 이름을, 받은 글이면 보낸 사람 이름을 쓴다.
    private var shareSenderName: String {
        post.isMine ? userName : post.senderName
    }

    var body: some View {
        card
            .fullScreenCover(isPresented: $showSharingScreen) {
                NearbySharingScreen(post: post) { showSharingScreen = false }
            }
    }

    private var card: some View {
        VStack(spacing: 24) {

            // Figma `Frame 9` 왼쪽 디자인: 136x55 알약 안에 64x48 버튼 둘
            HStack(spacing: 0) {
                Button {
                    showSharingScreen = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                }
                .buttonStyle(CardToolbarButtonStyle())
                .accessibilityLabel("가까운 친구에게 보내기")

                Button {
                    Task { await saveDrawingToGallery() }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title2)
                }
                .buttonStyle(CardToolbarButtonStyle())
                .accessibilityLabel("사진에 저장")
            }
            .frame(width: 136, height: 55)
            .glassEffect(.regular, in: .capsule)
            .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
            .padding(.bottom, 10)

            ZStack {
                // 앞면: 그림
                //
                // 접힌 모서리와 접힘 없는 둥근 사각형을 번갈아 보여준다.
                // 뒤집을 수 있는 카드라는 걸 가만히 알려주는 신호다.
                //
                // 반경은 그리던 캔버스와 같은 값이라 그림이 잘린 모양과 정확히 맞물린다.
                // 색도 에셋에서 뽑은 값이라 두 상태를 오갈 때 본체 색이 흔들리지 않는다.
                Group {
                    if showFold {
                        Image(.memoFront)
                            .resizable()
                    } else {
                        RoundedRectangle(cornerRadius: DoodleMetrics.canvasCornerRadius)
                            .fill(Color.doodlePaper)
                    }
                }
                .frame(width: DoodleMetrics.canvasSize.width, height: DoodleMetrics.canvasSize.height)
                .shadow(color: .black.opacity(0.25), radius: 10)
                .overlay { DoodleImageView(drawingData: post.drawingData) }
                .opacity(isFlipped ? 0 : 1)

                // 뒷면: 정보
                //
                // 앞면과 같은 주기로 접혔다 펴진다. 뒷면은 글씨가 가운데에 모여 있어
                // 접힌 모서리와 겹치지 않는다.
                //
                // memoBack 에셋에는 좌하단이 어두워지는 그라디언트가 들어 있어
                // 뒤집는 순간 앞면에 없던 음영이 생긴다. 그래서 앞면용 에셋을 쓴다.
                Group {
                    if showFold {
                        // 좌우를 뒤집어 두어 접힌 모서리가 오른쪽 아래에 온다.
                        Image(.memoFront)
                            .resizable()
                            .scaleEffect(x: -1, y: 1)
                    } else {
                        RoundedRectangle(cornerRadius: DoodleMetrics.canvasCornerRadius)
                            .fill(Color.doodlePaper)
                    }
                }
                .frame(width: DoodleMetrics.canvasSize.width, height: DoodleMetrics.canvasSize.height)
                .shadow(color: .black.opacity(0.25), radius: 10)
                .overlay { backFaceContent }
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
        // 접힌 모서리를 일정 간격으로 나타냈다 감춘다.
        // Timer 대신 task 를 쓰면 화면이 사라질 때 알아서 멈춘다.
        .task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: Self.foldInterval)
                } catch {
                    break
                }
                withAnimation(.easeInOut(duration: Self.foldFade)) { showFold.toggle() }
            }
        }
        .alert("사진 저장", isPresented: $showSaveAlert) {
            Button("확인") { }
        } message: {
            Text(saveMessage)
        }
    }

    // MARK: - 뒷면

    /// 카드 뒷면. Figma `Frame 6`(10:406) 기준.
    ///
    /// 내가 그린 카드와 받은 카드가 같은 레이아웃을 쓰고 문구만 달라진다.
    @ViewBuilder
    private var backFaceContent: some View {
        ZStack {
            // 본문은 카드 정가운데. 위아래 요소에 밀리지 않도록 따로 겹쳐 놓는다.
            Text(post.text.isEmpty ? "(텍스트 없음)" : post.text)
                .font(.system(size: 30, weight: .medium))
                // Figma 행간 44. 30pt 본문의 기본 행높이에 약 8 을 더하면 비슷해진다.
                .lineSpacing(8)
                .foregroundStyle(Color.doodlePrimary)
                .multilineTextAlignment(.center)
                .frame(width: 253)

            VStack(spacing: 0) {
            if !counterpartName.isEmpty {
                HStack(spacing: 10) {
                    avatar

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(counterpartName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.doodlePrimary)

                        Text(counterpartSuffix)
                            .font(.system(size: 16))
                            .foregroundStyle(Color.doodleSecondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.leading, 20)
                .padding(.top, 19)
            }

            Spacer()

            Text(post.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 12))
                .foregroundStyle(Color.doodleDetail)
                .padding(.bottom, 27)
            }
        }
    }
}

/// Figma `Frame 9` 왼쪽 디자인의 버튼. 누르면 회색 10% 배경이 깔린다.
private struct CardToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.doodlePrimary)
            .frame(width: 64, height: 48)
            .background {
                if configuration.isPressed {
                    Capsule().fill(Color.doodlePressed)
                }
            }
            .contentShape(Capsule())
    }
}

extension PostDetailView {

    /// 카드 뒷면 위쪽에 보여줄 상대. 내가 그렸으면 받는 사람, 받았으면 보낸 사람.
    private var counterpartName: String {
        post.isMine ? post.recipientName : post.displaySenderName
    }

    private var counterpartSuffix: String {
        post.isMine ? "님에게" : "님이 보냄"
    }

    /// 상대 자리에 넣을 그림. 내가 그린 카드에는 내 프로필을 쓴다.
    private var counterpartDrawingData: Data? {
        let data = post.isMine ? profilePosts.first?.drawingData : post.senderProfileDrawingData
        guard let data, !data.isEmpty else { return nil }
        return data
    }

    /// Figma: 흰 원 55 + #E1E1E1 테두리, 안에 그림 30.
    private var avatar: some View {
        ZStack {
            Circle()
                .fill(.white)
                .overlay { Circle().stroke(Color.doodleHairline, lineWidth: 1) }

            Group {
                if let counterpartDrawingData {
                    DoodleImageView(drawingData: counterpartDrawingData)
                } else {
                    Image(.profileDefault)
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(width: 30, height: 30)
        }
        .frame(width: 55, height: 55)
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
        DoodleImageView(drawingData: post.drawingData)
            .frame(width: DoodleMetrics.canvasSize.width, height: DoodleMetrics.canvasSize.width)
            .background(.white)
    }

    private func present(_ message: String) {
        saveMessage = message
        showSaveAlert = true
    }
}

#Preview {
    PostDetailView(post: Post(drawingData: Data(), text: "테스트", isMine: false))
        .modelContainer(LocalDataStore.makePreviewContainer())
}
