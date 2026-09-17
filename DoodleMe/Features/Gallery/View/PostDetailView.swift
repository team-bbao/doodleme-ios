//
//  PostDetailView.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/11/26.
//

import SwiftData
import SwiftUI

struct PostDetailView: View {
    let post: Post
    /// 조작부(뒤로 버튼)가 쓰는 배율. 갤러리 상단 버튼과 같은 값을 받아 크기를 맞춘다.
    ///
    /// 여기서 직접 재지 않는 이유가 있다 — 이 뷰가 재는 크기는 안전영역 안쪽이라
    /// 갤러리가 재는 화면 전체와 기준이 달라, 같은 기기에서 버튼이 1pt 어긋난다.
    var chromeScale: CGFloat = 1
    /// 확대를 닫고 그리드로 돌아간다.
    var onClose: () -> Void

    @State private var isFlipped = false
    /// 앞면에 접힌 모서리를 보여줄 차례인지.
    @State private var showFold = false

    /// 뒤로 버튼이 화면 좌상단에서 떨어진 거리. Figma (18, 72).
    private static let backButtonLeading: CGFloat = 18
    private static let backButtonTop: CGFloat = 72

    /// 확대된 카드 크기. Figma `iPhone 17 - 17` 의 `메모지 1`(141:698).
    /// 그리기 캔버스(350x390)와 별개다 — 캔버스를 건드리면 그리기 탭이 흔들린다.
    private static let cardSize = CGSize(width: 362, height: 396)

    /// 옆 칸으로 놓일 때 이만큼이면 카드가 편히 들어간다.
    ///
    /// 카드(362)에 좌우 여백을 더한 값이다. 그 이상은 낭비다 —
    /// 카드가 350x390 고정 비율이라 칸만 넓혀도 카드가 커지지 않는다.
    /// 넓이는 격자 쪽이 쓰는 것이 낫다.
    static var preferredPaneWidth: CGFloat { cardSize.width + horizontalChrome }
    /// 한마디 글자 크기와 행높이. Figma `Frame 35`(92:828).
    private static let messageFontSize: CGFloat = 40
    private static let messageLineHeight: CGFloat = 44
    /// 알약 툴바 안쪽 좌우 여백과 버튼 사이 간격. Figma: 칩이 x=5 에서 시작해 60 폭.
    private static let toolbarInset: CGFloat = 5
    private static let toolbarButtonSpacing: CGFloat = 6
    /// 알약 높이와 그 안 버튼 한 칸의 폭. Figma `Group 4`.
    private static let baseToolbarHeight: CGFloat = 48
    private static let toolbarButtonWidth: CGFloat = 60

    /// 알약 높이.
    ///
    /// 넓은 화면에서는 **뒤로 버튼과 같은 크기**가 된다 — 같은 화면에 나란히 떠 있는
    /// 조작부인데 하나는 60, 하나는 48 이면 한 벌로 보이지 않는다.
    /// 아이폰은 Figma 의 48 그대로다.
    private var toolbarHeight: CGFloat {
        chromeScale == 1 ? Self.baseToolbarHeight : DoodleMetrics.side(scale: chromeScale)
    }

    /// 알약 안쪽 치수가 높이와 같은 비율로 자란다.
    private var toolbarScale: CGFloat { toolbarHeight / Self.baseToolbarHeight }
    /// 알약 안 글리프 크기. `.title2` 와 같은 22 다.
    private static let toolbarGlyphSize: CGFloat = 22

    /// 알약 폭. 60 폭 버튼 `n` 개 + 사이 6 + 좌우 여백 5 둘.
    ///
    /// 내가 그린 것에는 「카드로 공유」 가 빠져 둘이 되므로 개수를 받아 잰다.
    /// 셋이면 192, 둘이면 136 — Figma `Group 4` 의 원래 값이다.
    private static func toolbarWidth(buttons: Int) -> CGFloat {
        toolbarButtonWidth * CGFloat(buttons) + toolbarButtonSpacing * CGFloat(buttons - 1) + toolbarInset * 2
    }

    /// 다 접혔을 때 접힌 정사각형 한 변의 길이.
    /// memoFront 에셋의 접힌 자리를 캔버스 크기로 환산한 값이다.
    private static let foldSize: CGFloat = 100
    /// 접힘을 보여줬다 감추는 주기. 한 상태가 이만큼 머문다.
    private static let foldInterval: Duration = .milliseconds(1250)
    /// 두 상태를 오갈 때 걸리는 시간. 주기에 비해 길면 계속 움직이는 느낌이 든다.
    private static let foldFade: TimeInterval = 0.35
    @State private var showSharingScreen = false
    /// 내보낼 카드를 먼저 보여 주는 화면이 떠 있는지.
    @State private var showExportPreview = false

    /// 화면이 실제로 준 크기. 넓은 화면에서 카드를 키우는 데 쓴다.
    @State private var screenSize = CGSize(width: DoodleLayout.baseContentWidth,
                                           height: DoodleLayout.baseHeight)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// 카드 덩이를 지금 화면에 맞게 키우는 배율. 아이폰에서는 늘 1 배다.
    ///
    /// 카드가 362x396 에 못박혀 있어 아이폰(402 폭)에서는 90% 를 채우지만
    /// 아이패드(820)에서는 44% 밖에 안 돼, 작은 카드 하나가 위쪽에 떠 있고 아래가 텅 빈다.
    ///
    /// 가로 폭은 `DoodleLayout` 이 정하고, 거기서 **세로가 감당할 만큼**으로 한 번 더 깎는다.
    /// 눕히면 높이가 모자라기 때문이다 — 11인치를 눕히면 폭은 1180 이지만 높이는 820 이다.
    private var cardScale: CGFloat {
        let byWidth = DoodleLayout.scale(forWidth: screenSize.width,
                                         sizeClass: horizontalSizeClass)
        guard byWidth > 1, screenSize.height > 0 else { return 1 }
        let room = screenSize.height - Self.verticalChrome
        let byHeight = room / Self.baseBlockHeight

        // 펼쳐 놓으면 카드가 **두 장** 나란히 서므로 폭도 따로 본다.
        // 이것 없이 세로 기준만 쓰면 눕혔을 때 두 장이 화면 좌우로 넘쳐 잘린다 — 실제로 그랬다.
        let byPairWidth = isSpread
            ? (screenSize.width - Self.horizontalChrome) / (Self.cardSize.width * 2 + 24)
            : .greatestFiniteMagnitude

        return max(1, min(byWidth, byHeight, byPairWidth))
    }

    /// 펼쳤을 때 좌우로 비워 두는 몫. 바깥 여백과 그림자 자리다.
    private static let horizontalChrome: CGFloat = 140

    /// 카드 덩이가 쓸 수 없는 세로 몫.
    ///
    /// 안전영역(위 24 · 아래 21)과 바깥 여백을 뺀다.
    /// 빼지 않으면 눕혔을 때 덩이가 화면 높이를 꽉 채워 툴바가 위로 잘려 나간다 —
    /// 실제로 그렇게 나왔다.
    private static let verticalChrome: CGFloat = 120

    /// 카드 덩이에서 **배율을 먹는 부분**이 쓰는 세로 길이.
    /// 툴바 48 + 사이 24 + 카드 396 = 468. 아래 여백 80 은 키우지 않으므로 뺀다.
    private static let baseBlockHeight: CGFloat = 468

    /// 갤러리 머리말이 쓰는 것과 같은 이름. 내보내기 카드의 제목에 들어간다.
    @AppStorage("userName") private var userName = ""
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
        .onGeometryChange(for: CGSize.self) { $0.size } action: { screenSize = $0 }
        .fullScreenCover(isPresented: $showSharingScreen) {
            NearbySharingScreen(post: post) { showSharingScreen = false }
        }
        .fullScreenCover(isPresented: $showExportPreview) {
            ExportPreviewScreen(
                pages: [ExportPage(id: 0) { ExportSinglePostCard(post: post, myName: myName) }],
                fileName: "doodleme-\(post.persistentModelID.hashValue.magnitude)"
            ) {
                showExportPreview = false
            }
        }
    }

    /// 제목의 「○○의 첫인상」 자리에 들어갈 내 이름.
    ///
    /// 갤러리 머리말에서 고친 이름과 같은 값을 본다.
    private var myName: String {
        userName.isEmpty ? "나" : userName
    }

    /// Figma `iPhone 17 - 14` 의 `Frame 6`: 화면 좌상단 (18, 72) 에 44x44.
    ///
    /// 예전에는 어두운 배경을 눌러야 닫혔다.
    /// 눌러야 할 곳이 보이지 않으면 처음 온 사람은 빠져나갈 방법을 찾지 못한다.
    private var backButton: some View {
        Button(action: onClose) {
            // 흰 원을 직접 그리지 않는다. 그림 위에 떠 있는 조작부라 유리가 맞는 자리다 —
            // 애플 HIG 「Materials」: *Liquid Glass forms a distinct functional layer for
            // controls and navigation elements … that floats above the content layer.*
            //
            // 재질을 `buttonStyle(.glass)` 가 아니라 `glassEffect` 로 입힌다.
            // 버튼 스타일은 라벨 바깥에 제 여백을 더해 **프레임보다 크게 그린다** —
            // 60 을 줬는데 실제 원은 그보다 커져서, 바로 아래 카드 툴바(60)와 눈에 띄게 어긋났다.
            // 알약 툴바가 쓰는 방식과 같게 하면 크기가 정확히 맞는다.
            Image(systemName: "chevron.backward")
                .font(.system(size: 18 * chromeScale, weight: .medium))
                .foregroundStyle(Color.doodlePrimary)
                .frame(width: DoodleMetrics.side(scale: chromeScale),
                       height: DoodleMetrics.side(scale: chromeScale))
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        // 자리도 함께 자란다. 버튼만 키우면 넓은 화면에서 모서리에 바짝 붙는다.
        .padding(.leading, Self.backButtonLeading * chromeScale)
        .padding(.top, Self.backButtonTop * chromeScale)
        .accessibilityLabel("뒤로")
    }

    private var card: some View {
        VStack(spacing: 24 * cardScale) {

            // Figma `iPhone 17 - 17`(평소) · `iPhone 17 - 14`(눌림) 의 `Group 4`.
            // 원래 흰색 80% 알약 136x48 안에 60 폭 버튼 둘이었고, 내보내기가 늘어 셋이 되었다.
            // 알약 안쪽도 함께 키운다.
            //
            // 예전에는 바깥 `frame` 에만 `cardScale` 을 걸어, 13인치에서 알약은 341 로 커지는데
            // 안의 버튼 셋은 아이폰 크기(202)로 남아 좌우에 빈 유리가 70 씩 남았다.
            HStack(spacing: Self.toolbarButtonSpacing * toolbarScale) {
                Button {
                    showSharingScreen = true
                } label: {
                    // AirDrop 으로 건네는 동작이라 내보내기 화살표보다 이쪽이 뜻이 맞는다.
                    Image(systemName: "airplay.audio")
                        .font(toolbarGlyphFont)
                }
                .buttonStyle(CardToolbarButtonStyle(scale: toolbarScale))
                .accessibilityLabel("가까운 친구에게 보내기")

                // 사진 앱에 **그림만** 남긴다. 흰 바탕에 획뿐이고 종이도 제목도 없다 —
                // `snapshotData()` 에 그 뜻이 적혀 있다: 「사진첩에 남는 건 그림이지 종이가 아니다」.
                //
                // 옆의 공유 버튼과 겹치지 않는다.
                // 애플 HIG 「Activity views」 가 금하는 것은 **액티비티 뷰에 이미 있는 동작**을
                // 따로 만드는 것인데, 공유 시트가 넘기는 것은 종이·제목·꼬리말이 붙은 **카드**다.
                // 남는 결과물이 서로 달라 중복이 아니다.
                Button {
                    Task { await saveDrawingToGallery() }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(toolbarGlyphFont)
                }
                .buttonStyle(CardToolbarButtonStyle(scale: toolbarScale))
                .accessibilityLabel("그림만 사진에 저장")

                // 내보내기 카드를 먼저 보여 주고, 거기서 시스템 공유 시트로 넘긴다.
                // 사진 저장·인스타그램·AirDrop 이 모두 그 시트 안에 들어 있다.
                //
                // 받은 것이든 내가 그린 것이든 낼 수 있다.
                // 제목의 두 이름이 자리를 바꿀 뿐이다 — `ExportSinglePostCard` 참고.
                Button {
                    showExportPreview = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(toolbarGlyphFont)
                }
                .buttonStyle(CardToolbarButtonStyle(scale: toolbarScale))
                .accessibilityLabel("카드로 공유")
            }
            .padding(.horizontal, Self.toolbarInset * toolbarScale)
            .frame(width: Self.toolbarWidth(buttons: 3) * toolbarScale,
                   height: toolbarHeight)
            // 흰 알약 대신 유리. 갤러리 하단 선택 바와 같은 재질이다.
            // 안에 누를 것이 셋 들어 있으므로 HIG 대로 `interactive` 를 건다.
            .glassEffect(.regular.interactive(), in: .capsule)
            .padding(.bottom, 10)

            // 넓고 낮은 화면(아이패드 가로)에서는 앞뒤를 나란히 편다.
            //
            // 좌우가 크게 남는데 카드 하나만 가운데 서 있으면 그 자리가 버려진다.
            // 펼쳐 놓으면 그림과 한마디를 한눈에 본다 — 뒤집을 필요가 없어지므로
            // 그 화면에서는 뒤집기도 끄고 접힘 신호도 내지 않는다.
            if isSpread {
                HStack(spacing: 24 * cardScale) {
                    frontFace
                    backFace
                }
                .padding(.bottom, 80)
            } else {
                ZStack {
                    frontFace
                        .opacity(isFlipped ? 0 : 1)

                    backFace
                        .opacity(isFlipped ? 1 : 0)
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                }
                // 아래 여백은 키우지 않는다.
                // 카드를 화면 한가운데보다 조금 위에 두려고 넣은 값인데,
                // 배율을 먹이면 아이패드에서 120 이 되어 덩이가 위로 치우친다.
                .padding(.bottom, 80)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .animation(.easeInOut(duration: 0.5), value: isFlipped)
                .onTapGesture {
                    isFlipped.toggle()
                }
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

    /// 앞면: 그림.
    ///
    /// 접힌 모서리와 접힘 없는 둥근 사각형을 번갈아 보여준다.
    /// 뒤집을 수 있는 카드라는 걸 가만히 알려주는 신호다.
    ///
    /// 반경은 그리던 캔버스와 같은 값이라 그림이 잘린 모양과 정확히 맞물린다.
    private var frontFace: some View {
        paperFace
            .frame(width: Self.cardSize.width * cardScale,
                   height: Self.cardSize.height * cardScale)
            .shadow(color: .black.opacity(0.25), radius: 10)
            .overlay {
                DoodleImageView(drawingData: post.drawingData)
                    .mask { frontMask }
            }
    }

    /// 뒷면: 보낸 사람과 한마디.
    ///
    /// memoBack 에셋에는 좌하단이 어두워지는 그라디언트가 들어 있어
    /// 뒤집는 순간 앞면에 없던 음영이 생긴다. 그래서 앞면용 에셋을 쓴다.
    /// 좌우를 뒤집어 두어 접힌 모서리가 오른쪽 아래에 온다.
    private var backFace: some View {
        paperFace
            .scaleEffect(x: -1, y: 1)
            .frame(width: Self.cardSize.width * cardScale,
                   height: Self.cardSize.height * cardScale)
            .shadow(color: .black.opacity(0.25), radius: 10)
            .overlay { backFaceContent }
    }

    /// 알약 안 글리프의 글꼴.
    ///
    /// 배율이 1 인 화면에서는 `.title2` 를 그대로 쓴다. 고정 크기로 바꿔 두면
    /// 이 앱에서 **유일하게 큰 글자 설정을 따르던 자리**가 사라진다.
    /// 키워야 할 때만 고정 크기로 내려간다 — 큰 글자와 배율을 함께 곱할 수는 없다.
    private var toolbarGlyphFont: Font {
        toolbarScale == 1 ? .title2 : .system(size: Self.toolbarGlyphSize * toolbarScale)
    }

    /// 앞뒤를 나란히 펼칠지.
    ///
    /// 넓고 **낮은** 화면에서만 편다 — 아이패드를 눕혔을 때다.
    /// 세로로 세우면 좌우가 남지 않아 나란히 놓을 자리가 없고, 아이폰은 어느 방향이든 좁다.
    private var isSpread: Bool {
        DoodleLayout.isWide(screenSize.width, sizeClass: horizontalSizeClass)
            && screenSize.width > screenSize.height
    }

    /// 지금 접힌 정도. 0 이면 펴진 상태.
    ///
    /// 펼쳐 놓았으면 접지 않는다. 접힘은 「뒤집을 수 있다」 는 신호인데
    /// 이미 뒤가 보이는 자리에서는 알릴 것이 없다.
    private var foldDepth: CGFloat { (showFold && !isSpread ? Self.foldSize : 0) * cardScale }

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
            FoldedPaperShape(depth: foldDepth, cornerRadius: DoodleMetrics.canvasCornerRadius * cardScale)
                .fill(LinearGradient.doodlePaperFace)

            FoldFlapShape(depth: foldDepth)
                .fill(Color.doodleFoldFlap)
        }
    }

    /// 앞면의 그림을 가릴 마스크. 접힌 정사각형 자리에는 그림이 얹히지 않는다.
    private var frontMask: some View {
        PaperBodyShape(depth: foldDepth, cornerRadius: DoodleMetrics.canvasCornerRadius * cardScale)
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
                font: .doodleHandwriting(size: Self.messageFontSize * cardScale),
                lineHeight: Self.messageLineHeight * cardScale,
                color: UIColor(Color.doodlePrimary)
            )
            .frame(width: 253 * cardScale)

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
    /// 카드와 함께 커지는 배율. 알약 바깥만 키우면 버튼이 그 안에서 겉돈다.
    var scale: CGFloat = 1

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.doodlePrimary)
            .frame(width: 60 * scale, height: 48 * scale)
            .background {
                if configuration.isPressed {
                    Capsule()
                        .fill(Color.doodleCardToolbarPressed)
                        .frame(height: 42 * scale)
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
    /// 상대가 자기 프로필 그림을 함께 보냈으면 그것을 쓴다.
    /// 그림을 받을 때 `senderProfileDrawingData` 로 함께 실려 와 저장돼 있다.
    ///
    /// 없으면 `Frame 34` 의 다섯 낙서 중 하나로 대신한다.
    /// 매번 새로 뽑으면 화면이 다시 그려질 때마다 얼굴이 바뀌므로,
    /// 이름을 해시해 고른다. 흩어져 보이면서도 같은 사람에게는 늘 같은 얼굴이 붙는다.
    ///
    /// 내가 그린 그림에는 받는 사람의 프로필이 있을 수 없다.
    /// 건네줄 상대를 이름으로만 적어 두기 때문이라, 그쪽은 늘 대신 쓰는 얼굴이 나온다.
    private var avatar: some View {
        ZStack {
            Circle()
                .fill(.white)
                .overlay { Circle().stroke(Color.doodleHairline, lineWidth: 1) }

            if let profileData = post.senderProfileDrawingData, !post.isMine {
                // 받은 프로필은 원을 꽉 채운다.
                // 대신 쓰는 낙서(30)와 같은 크기로 두면 그림이 원 한가운데
                // 작게 떠서, 진짜 프로필이 왔다는 것이 읽히지 않는다.
                DoodleImageView(drawingData: profileData, contentMode: .fill)
                    .frame(width: Self.avatarDiameter, height: Self.avatarDiameter)
                    .clipShape(Circle())
            } else {
                Image(PeerAvatarPalette.image(for: counterpartName))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
            }
        }
        .frame(width: Self.avatarDiameter, height: Self.avatarDiameter)
    }

    /// 카드 뒷면 아바타 원의 지름. Figma 의 55.
    private static let avatarDiameter: CGFloat = 55

    // MARK: - 사진 저장

    /// 사진 앱에 그림을 저장한다. 실제로 굽고 쓰는 일은 `PhotoLibrarySaver` 가 맡는다.
    private func saveDrawingToGallery() async {
        present(await PhotoLibrarySaver.save([post.photoItem]).message)
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
private nonisolated struct FoldedPaperShape: Shape {
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
private nonisolated struct FoldFlapShape: Shape {
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
private nonisolated struct PaperBodyShape: Shape {
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
