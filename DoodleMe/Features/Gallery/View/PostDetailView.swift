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
    /// 확대를 닫고 그리드로 돌아간다.
    var onClose: () -> Void

    /// 내가 그린 카드의 아바타로 쓸 내 프로필 그림.
    @Query(filter: #Predicate<Post> { $0.isProfile }) private var profilePosts: [Post]

    @State private var isFlipped = false
    /// 앞면에 접힌 모서리를 보여줄 차례인지.
    @State private var showFold = false

    /// 다 접혔을 때 접힌 정사각형 한 변의 길이.
    /// memoFront 에셋의 접힌 자리를 캔버스 크기로 환산한 값이다.
    private static let foldSize: CGFloat = 100
    /// 접힘을 보여줬다 감추는 주기. 한 상태가 이만큼 머문다.
    private static let foldInterval: Duration = .milliseconds(1250)
    /// 두 상태를 오갈 때 걸리는 시간. 주기에 비해 길면 계속 움직이는 느낌이 든다.
    private static let foldFade: TimeInterval = 0.35
    @State private var showSharingScreen = false
    @State private var showSaveAlert = false
    @State private var saveMessage = ""

    var body: some View {
        // 뒤로가기는 카드가 아니라 **화면** 좌상단에 붙는다.
        // 카드에 얹으면 카드가 가운데 있으므로 버튼도 따라 내려와 그림 위를 덮는다.
        ZStack {
            card

            backButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .fullScreenCover(isPresented: $showSharingScreen) {
            NearbySharingScreen(post: post) { showSharingScreen = false }
        }
    }

    /// Figma `iPhone 17 - 14` 의 `Frame 6`: 화면 좌상단 (18, 72) 에 44x44.
    ///
    /// 예전에는 어두운 배경을 눌러야 닫혔다.
    /// 눌러야 할 곳이 보이지 않으면 처음 온 사람은 빠져나갈 방법을 찾지 못한다.
    private var backButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.doodlePrimary)
                .frame(width: DoodleMetrics.buttonSide, height: DoodleMetrics.buttonSide)
                .background(.white, in: Circle())
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        }
        .padding(.leading, 18)
        .padding(.top, 72)
        .accessibilityLabel("닫기")
    }

    private var card: some View {
        VStack(spacing: 24) {

            // Figma `Frame 9` 왼쪽 디자인: 136x55 알약 안에 64x48 버튼 둘
            HStack(spacing: 0) {
                Button {
                    showSharingScreen = true
                } label: {
                    // Figma `iPhone 17 - 14` 의 왼쪽 버튼 글리프.
                    // AirDrop 으로 건네는 동작이라 내보내기 화살표보다 이쪽이 뜻이 맞는다.
                    Image(systemName: "airplay.audio")
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
            .frame(width: 136, height: DoodleMetrics.buttonSide)
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
                paperFace
                    .frame(width: DoodleMetrics.canvasSize.width, height: DoodleMetrics.canvasSize.height)
                .shadow(color: .black.opacity(0.25), radius: 10)
                .overlay {
                    DoodleImageView(drawingData: post.drawingData)
                        .mask { frontMask }
                }
                .opacity(isFlipped ? 0 : 1)

                // 뒷면: 정보
                //
                // 앞면과 같은 주기로 접혔다 펴진다. 뒷면은 글씨가 가운데에 모여 있어
                // 접힌 모서리와 겹치지 않는다.
                //
                // memoBack 에셋에는 좌하단이 어두워지는 그라디언트가 들어 있어
                // 뒤집는 순간 앞면에 없던 음영이 생긴다. 그래서 앞면용 에셋을 쓴다.
                // 좌우를 뒤집어 두어 접힌 모서리가 오른쪽 아래에 온다.
                paperFace
                    .scaleEffect(x: -1, y: 1)
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

    /// 지금 접힌 정도. 0 이면 펴진 상태.
    private var foldDepth: CGFloat { showFold ? Self.foldSize : 0 }

    /// 접혔다 펴지는 종이 한 장.
    ///
    /// 예전에는 접힌 종이 이미지를 불투명도로 나타냈다 감췄다.
    /// 그러면 종이가 접히는 게 아니라 모서리가 투명해졌다 나타나는 것처럼 보인다.
    ///
    /// 지금은 접힌 크기 자체를 키웠다 줄인다.
    /// 모서리가 실제로 접혀 들어오는 것처럼 보이고,
    /// 잘려나가는 삼각형과 접혀 올라온 삼각형이 늘 짝을 이룬다.
    private var paperFace: some View {
        ZStack {
            FoldedPaperShape(depth: foldDepth, cornerRadius: DoodleMetrics.canvasCornerRadius)
                .fill(Color.doodlePaper)

            FoldFlapShape(depth: foldDepth)
                .fill(Color.doodleFoldFlap)
        }
    }

    /// 앞면의 그림을 가릴 마스크. 접힌 정사각형 자리에는 그림이 얹히지 않는다.
    private var frontMask: some View {
        PaperBodyShape(depth: foldDepth, cornerRadius: DoodleMetrics.canvasCornerRadius)
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

                        if !counterpartSuffix.isEmpty {
                            Text(counterpartSuffix)
                                .font(.system(size: 16))
                                .foregroundStyle(Color.doodleSecondary)
                        }
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
            // 아이콘 둘이 나란히 든 알약이라, 높이는 44 로 맞추고 폭만 알약 절반으로 나눈다.
            .frame(width: 68, height: DoodleMetrics.buttonSide)
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

    /// 이름 뒤에 붙일 말. 내가 그린 것에는 아무것도 붙이지 않는다.
    private var counterpartSuffix: String {
        post.isMine ? "" : "님이 보냄"
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
                    DefaultDoodleImage(lineWidth: 1)
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
    ///
    /// 높이에 너비를 넣어 두어 저장된 사진이 정사각형이 되고, 그림이 그만큼 작게 담겼다.
    /// 캔버스 비율을 그대로 써야 그린 대로 저장된다.
    private var drawingSnapshot: some View {
        DoodleImageView(drawingData: post.drawingData)
            .frame(width: DoodleMetrics.canvasSize.width, height: DoodleMetrics.canvasSize.height)
            .background(.white)
    }

    private func present(_ message: String) {
        saveMessage = message
        showSaveAlert = true
    }
}

#Preview {
    PostDetailView(post: Post(drawingData: Data(), text: "테스트", isMine: false)) { }
        .modelContainer(LocalDataStore.makePreviewContainer())
}

// MARK: - 접힌 종이 도형

/// 왼쪽 아래 모서리가 접혀 잘려나간 종이.
///
/// 접힌 자리는 한 변이 `depth` 인 정사각형이고, 그 대각선을 접는 선으로 본다.
/// 대각선 아래쪽 삼각형은 뜯겨 나가고, 위쪽 삼각형이 접혀 올라온다.
private struct FoldedPaperShape: Shape {
    var depth: CGFloat
    var cornerRadius: CGFloat

    var animatableData: CGFloat {
        get { depth }
        set { depth = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let paper = Path(roundedRect: rect, cornerRadius: cornerRadius)
        guard depth > 0 else { return paper }

        var cut = Path()
        cut.move(to: CGPoint(x: rect.minX, y: rect.maxY - depth))
        cut.addLine(to: CGPoint(x: rect.minX + depth, y: rect.maxY))
        cut.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        cut.closeSubpath()

        return paper.subtracting(cut)
    }
}

/// 접혀 올라온 삼각형. 잘려나간 삼각형을 접는 선에 대고 뒤집은 모양이다.
private struct FoldFlapShape: Shape {
    var depth: CGFloat

    var animatableData: CGFloat {
        get { depth }
        set { depth = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard depth > 0 else { return path }

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - depth))
        path.addLine(to: CGPoint(x: rect.minX + depth, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + depth, y: rect.maxY - depth))
        path.closeSubpath()
        return path
    }
}

/// 그림이 보여도 되는 자리. 접힌 정사각형 전체를 뺀다.
///
/// 잘려나간 쪽뿐 아니라 접혀 올라온 쪽에도 그림이 얹히면 안 된다.
/// 접힌 종이의 뒷면에 그림이 이어질 리가 없기 때문이다.
private struct PaperBodyShape: Shape {
    var depth: CGFloat
    var cornerRadius: CGFloat

    var animatableData: CGFloat {
        get { depth }
        set { depth = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let paper = Path(roundedRect: rect, cornerRadius: cornerRadius)
        guard depth > 0 else { return paper }

        let corner = Path(CGRect(x: rect.minX, y: rect.maxY - depth, width: depth, height: depth))
        return paper.subtracting(corner)
    }
}
