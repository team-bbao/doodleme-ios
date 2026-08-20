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

    @State private var isFlipped = false
    /// 앞면에 접힌 모서리를 보여줄 차례인지.
    @State private var showFold = false

    /// 확대된 카드 크기. Figma `iPhone 17 - 17` 의 `메모지 1`(141:698).
    /// 그리기 캔버스(350x390)와 별개다 — 캔버스를 건드리면 그리기 탭이 흔들린다.
    private static let cardSize = CGSize(width: 362, height: 396)
    /// 한마디 글자 크기와 행높이. Figma `Frame 35`(92:828).
    private static let messageFontSize: CGFloat = 40
    private static let messageLineHeight: CGFloat = 44
    /// 알약 툴바 안쪽 좌우 여백과 버튼 사이 간격. Figma: 칩이 x=5 에서 시작해 60 폭.
    private static let toolbarInset: CGFloat = 5
    private static let toolbarButtonSpacing: CGFloat = 6

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

            // 저장 결과를 알리는 창. 프로필 확인창과 같은 유리 카드를 쓴다.
            //
            // 시스템 `alert` 로 띄우면 이 화면에서만 생김새가 달라진다.
            // 묻는 것이 없으니 버튼은 하나뿐이고, 그때는 카드가 폭을 다 쓴다.
            if showSaveAlert {
                Color.doodleChoosingScrim
                    .ignoresSafeArea()
                    .transition(.opacity)

                DoodleConfirmPopup(
                    title: "사진 저장",
                    message: saveMessage,
                    confirmTitle: "확인",
                    onConfirm: {
                        withAnimation(.spring(response: 0.3)) { showSaveAlert = false }
                    }
                )
            }
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
            Image(systemName: "chevron.backward")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.doodlePrimary)
                .frame(width: DoodleMetrics.buttonSide, height: DoodleMetrics.buttonSide)
                .background(.white, in: Circle())
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        }
        .padding(.leading, 18)
        .padding(.top, 72)
        .accessibilityLabel("뒤로")
    }

    private var card: some View {
        VStack(spacing: 24) {

            // Figma `iPhone 17 - 17`(평소) · `iPhone 17 - 14`(눌림) 의 `Group 4`.
            // 흰색 80% 알약 136x48 안에 60 폭 버튼 둘.
            HStack(spacing: Self.toolbarButtonSpacing) {
                Button {
                    showSharingScreen = true
                } label: {
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
            .padding(.horizontal, Self.toolbarInset)
            .frame(width: 136, height: 48)
            .background(.white.opacity(0.8), in: Capsule())
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
                    .frame(width: Self.cardSize.width, height: Self.cardSize.height)
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
                    .frame(width: Self.cardSize.width, height: Self.cardSize.height)
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
            // 모서리가 접혔다 펴지므로 그림이 아니라 도형으로 그린다.
            // 색은 그리드 카드와 같은 그라디언트를 본다.
            FoldedPaperShape(depth: foldDepth, cornerRadius: DoodleMetrics.canvasCornerRadius)
                .fill(LinearGradient.doodlePaperFace)

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
            // Figma `iPhone 17 - 14` 의 `Frame 35`(92:828) 자리다.
            // 디자인의 `RF대충쓴준우체v3` 30 대신 `캘리폰트 하루일기 젤리펜` 40 을 쓴다 — 사용자 지시.
            // 색 `#424242` / 행높이 44 / 폭 253 은 그대로다.
            //
            // 행높이 44 는 이 글꼴의 기본 행높이보다 낮아
            // SwiftUI `Text` 로는 잡히지 않는다. 자세한 사정은 `FixedLineHeightText` 에 있다.
            FixedLineHeightText(
                text: post.text.isEmpty ? "(텍스트 없음)" : post.text,
                font: .doodleHandwriting(size: Self.messageFontSize),
                lineHeight: Self.messageLineHeight,
                color: UIColor(Color.doodlePrimary)
            )
            .frame(width: 253)

            VStack(spacing: 0) {
            if !counterpartName.isEmpty {
                HStack(spacing: 13) {
                    avatar

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(counterpartName)
                            // Figma 는 Semi Bold 18 이지만 화면에서는 Bold 로 둔다.
                            //
                            // 한글은 Figma 가 지정한 글꼴(Inter)에 없어 폴백으로 그려지는데,
                            // 그 폴백이 iOS 의 `.semibold` 보다 굵게 나온다.
                            // 스펙대로 `.semibold` 를 주면 디자인보다 16% 옅어 medium 처럼 읽힌다.
                            // `.bold` 가 디자인 렌더와 가장 가깝다 (잉크량 93%).
                            .font(.system(size: 18, weight: .bold))
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

/// 카드 위에 뜬 알약 툴바의 버튼.
///
/// 평소에는 바탕이 없고(`iPhone 17 - 17`), 누르는 동안에만 회색 알약이 깔린다(`iPhone 17 - 14`).
/// 눌린 표시는 60x42 지만 누를 수 있는 자리는 알약 높이(48)를 다 쓴다.
/// 표시가 작다고 손가락이 닿는 자리까지 좁힐 이유는 없다.
private struct CardToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.doodlePrimary)
            .frame(width: 60, height: 48)
            .background {
                if configuration.isPressed {
                    Capsule()
                        .fill(Color.doodleCardToolbarPressed)
                        .frame(height: 42)
                }
            }
            .contentShape(Rectangle())
    }
}

extension PostDetailView {

    /// 카드 뒷면 위쪽에 보여줄 상대. 내가 그렸으면 받는 사람, 받았으면 보낸 사람.
    private var counterpartName: String {
        post.isMine ? post.recipientName : post.displaySenderName
    }

    /// 이름 뒤에 붙일 말. 그림이 오간 방향을 알려준다.
    ///
    /// 내가 그린 것은 상대에게 건네는 그림이라 "님에게",
    /// 받은 것은 상대가 건네준 그림이라 "님으로부터".
    private var counterpartSuffix: String {
        post.isMine ? "님에게" : "님으로부터"
    }

    /// Figma: 흰 원 55 + #E1E1E1 테두리, 안에 그림 30.
    ///
    /// 얼굴은 `Frame 34` 의 다섯 낙서 중 하나를 쓴다.
    /// 매번 새로 뽑으면 화면이 다시 그려질 때마다 얼굴이 바뀌므로,
    /// 이름을 해시해 고른다. 흩어져 보이면서도 같은 사람에게는 늘 같은 얼굴이 붙는다.
    private var avatar: some View {
        ZStack {
            Circle()
                .fill(.white)
                .overlay { Circle().stroke(Color.doodleHairline, lineWidth: 1) }

            Image(PeerAvatarPalette.image(for: counterpartName))
                .resizable()
                .scaledToFit()
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
        guard let data = snapshotData() else {
            present("이미지를 만들지 못했어요.")
            return
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            present("사진 접근 권한이 없어 저장하지 못했어요. 설정에서 허용해주세요.")
            return
        }

        do {
            try await Self.write(data)
            present("그림이 사진 앱에 저장됐어요.")
        } catch {
            present("저장에 실패했어요: \(error.localizedDescription)")
        }
    }

    /// 사진 앱에 실제로 쓰는 부분.
    ///
    /// 화면 밖으로 꺼내 격리를 끊어야 한다.
    /// `View` 안에 두면 메인 액터에 묶이고 넘기는 클로저도 함께 묶이는데,
    /// `performChanges` 는 PhotoKit 이 **자기 큐**에서 그 클로저를 부른다.
    /// 그러면 Swift 6 이 "여기는 메인이 아니다" 하고 앱을 끊는다 —
    /// 저장 버튼을 누를 때마다 `EXC_BREAKPOINT` 로 튕기던 것이 이것이었다.
    nonisolated private static func write(_ data: Data) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
        }
    }

    /// 사진 앱에 남길 이미지. 흰 바탕(`#FFFFFF`)에 획만 담는다.
    ///
    /// 화면의 메모지에는 그늘과 접힌 모서리가 있지만 사진에는 넣지 않는다.
    /// 사진첩에 남는 건 그림이지 종이가 아니다.
    ///
    /// SwiftUI `ImageRenderer` 로 `DoodleImageView` 를 굽지 않는다.
    /// 그 뷰는 `.task` 로 그림을 늦게 채우는데, 화면에 붙지 않은 뷰에서는 그 `task` 가 돌지 않는다.
    /// 그대로 구우면 획 없는 흰 종이만 저장된다.
    /// 캐시가 이미 구워 둔 그림이 있으니 흰 바탕에 얹기만 하면 된다.
    ///
    /// 캔버스 비율을 그대로 써야 그린 대로 저장된다.
    private func snapshotData() -> Data? {
        let drawing = DoodleImageCache.image(for: post.drawingData)
        let canvas = CGRect(origin: .zero, size: DoodleMetrics.canvasSize)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        // 사진에 투명한 자리를 남기지 않는다. 흰 바탕이 전부 채운다.
        format.opaque = true

        let image = UIGraphicsImageRenderer(size: canvas.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(canvas)
            drawing.draw(in: canvas)
        }
        return image.pngData()
    }

    private func present(_ message: String) {
        saveMessage = message
        withAnimation(.spring(response: 0.3)) { showSaveAlert = true }
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
