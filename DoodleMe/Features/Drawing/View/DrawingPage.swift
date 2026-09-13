//
//  DrawingPage.swift
//  DoodleMe
//

import SwiftData
import SwiftUI

struct DrawingPage: View {

    @Binding var selectedTabIndex: Int

    @State private var session = DrawingSession()

    /// 저장을 마치면 갤러리가 열어야 할 섹션. 갤러리와 저장소를 통해 주고받는다.
    @AppStorage(GallerySection.storageKey) private var gallerySection = GallerySection.receivedFromOthers.rawValue
    @AppStorage(Post.showsJustSavedKey) private var showsJustSavedPost = false

    @State private var inputText = ""
    @State private var recipientName = ""
    @State private var shakeAmount: CGFloat = 0
    @State private var showResetAlert = false
    /// 포스트잇이 벗겨지는 연출 단계. 화면 연출 전용이라 세션 모델에 두지 않는다.
    @State private var peelPhase: Int = 0
    @FocusState private var focusedField: DrawingFocusField?
    /// 키보드가 가리기 시작하는 높이. 키보드가 없으면 화면 맨 아래와 같다.
    @State private var keyboardTop: CGFloat = 0
    /// 화면(또는 창)의 크기. 도구 막대를 얼마나 내려 붙일지 정하는 데 쓴다.
    @State private var screenSize: CGSize = .zero

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    /// 카운트다운이 지금 돌아야 하는지.
    ///
    /// 앱이 내려가 있는 동안에도 시계는 계속 간다.
    /// 그대로 두면 돌아왔을 때 남은 시간이 한 번에 뭉텅 줄어 있다.
    /// 화면이 앞에 있을 때만 재도록 한다.
    private var countdownRuns: Bool {
        session.phase == .drawing && scenePhase == .active
    }

    private var canSave: Bool { !recipientName.isEmpty && !inputText.isEmpty }

    /// 타이머를 화면 맨 위에서 얼마나 내려 붙일지.
    ///
    /// 안전영역을 무시하고 화면 꼭대기부터 재기 때문에 상태표시줄과 툴바를 스스로 비켜야 한다.
    /// 안전영역을 따르면 단계마다 툴바가 생겼다 사라지면서 타이머가 위아래로 튄다.
    /// 상태표시줄(최대 62) + 툴바(44) 를 지나는 값이다.
    private static let countdownTopInset: CGFloat = 112

    /// 좌상단 제목의 자리. 갤러리와 같은 값을 쓴다.
    private static let titleLeadingInset: CGFloat = 20
    private static let titleTopInset: CGFloat = 70

    /// 캔버스를 화면 정중앙에서 얼마나 올릴지.
    /// 아래쪽 도구 막대와 탭바가 앉을 자리를 남기려고 위로 당겨 둔다.
    private static let canvasCenterOffset: CGFloat = -10

    /// 아이폰(402×874)에서 잰 세로 구성. 넓은 화면은 이 구성을 통째로 비례해 키운다.
    ///
    /// ```
    ///   0 ┬ 화면 꼭대기
    /// 112 ┼ 타이머 시작 ─┐
    /// 232 ┼ 종이 윗변    │ 120  ← timerToCanvas
    /// 622 ┼ 종이 밑변 ───┘ 510  ← compositionHeight
    /// 874 ┴ 화면 바닥
    /// ```
    ///
    /// 위 112 : 아래 252 = 112/364. 이 비율을 지키면 어느 화면에서나 같은 그림이 나온다.
    private static let compositionHeight: CGFloat = 510
    private static let timerToCanvas: CGFloat = 120
    private static let topShare: CGFloat = 112 / 364

    /// 타이머 위로 반드시 남길 자리.
    ///
    /// 아이패드는 탭 바가 **위에** 있다(`sidebarAdaptable`). 알약 밑변이 약 73 이라
    /// 그 아래로 숨 쉴 자리를 두고 100 으로 잡는다.
    /// 아이폰 비율(위 112 : 아래 252)을 그대로 쓰면 가로에서 위가 79 까지 좁아져
    /// 숫자가 탭 바에 3pt 까지 붙었다 — 아이폰은 탭 바가 아래에 있어 생기지 않던 일이다.
    private static let minTopMargin: CGFloat = 100

    /// 종이 밑변부터 화면 바닥까지 비워 둘 자리.
    ///
    /// 한때 157 로 잡았다 — 막대 52 + 아래 여백 40 + 홈 인디케이터 20 + 종이와 막대 사이 45.
    /// **재 보니 막대가 실제로 먹는 자리는 147 이었다.**
    /// 막대 높이가 57 이고, `safeAreaPadding` 이 물고 오는 아래 여백이 40 이 아니라 90 이다.
    /// 그러니 157 을 비워도 종이와 막대 사이에 **10** 밖에 남지 않는다 — 눕힌 mini 에서 둘이 붙어 보였다.
    /// 실측한 147 에 틈 45 를 더해 192 로 잡는다.
    ///
    /// 아이폰은 배율이 1 로 고정이라 이 값이 쓰이지 않는다.
    private static let toolPickerReserve: CGFloat = 192

    /// 도구 막대를 화면 바닥에서 얼마나 띄울지.
    ///
    /// 아이폰은 90 그대로다. 넓은 화면에서는 아래에 탭 바가 없어
    /// 90 을 그대로 두면 막대 밑에 140 가까운 빈 자리가 남고, 그만큼 종이가 못 큰다.
    private static func toolPickerBottomInset(in size: CGSize) -> CGFloat {
        size.width >= 600 ? 40 : 90
    }

    /// 카드와 키보드 사이에 남길 틈.
    private static let keyboardGap: CGFloat = 12

    private static let canvasSizeWidth = DoodleMetrics.canvasSize.width
    private static let canvasSizeHeight = DoodleMetrics.canvasSize.height

    /// 아이폰 구성을 몇 배로 키워 보여줄지.
    ///
    /// 화면 높이만 보면 된다 — 아이폰 구성이 세로 874 를 기준으로 짜여 있으므로
    /// 그 비율이 곧 배율이다. 이러면 타이머·간격·종이가 한 덩어리로 함께 커져
    /// 어느 기기, 어느 방향에서나 같은 화면을 보게 된다.
    ///
    /// 아이폰에서는 874/874 = 1 이라 지금까지와 한 점도 다르지 않다.
    private static func canvasScale(in size: CGSize) -> CGFloat {
        // 아이폰은 손대지 않는다.
        //
        // 가장 넓은 아이폰도 세로로 세우면 440 을 넘지 않는다.
        // 문턱을 600 에 두면 아이폰에서는 늘 1 이 나와, 지금까지의 화면이 그대로 남는다.
        guard size.width >= 600, size.height > 0 else { return 1 }

        // 좌우가 모자라면 그쪽에 맞춘다. 실제로는 아이패드에서 걸리는 일이 없다.
        let byWidth = (size.width - 40) / canvasSizeWidth

        // 예전에는 `높이 / 874` 를 썼다. 그런데 가로로 눕히면 높이가 834 로 874 보다
        // 짧아져 배율이 1 에서 멈췄다 — 위아래가 텅 빈 채로 종이만 아이폰 크기였다.
        // 874 는 아이폰 화면 높이일 뿐, 종이가 쓸 수 있는 자리와는 상관이 없다.
        //
        // 그래서 「무엇이 꼭 있어야 하는지」로 바꿔 잡는다.
        // 위로는 제목이 앉을 자리, 아래로는 도구 막대가 앉을 자리를 남기고 나머지를 종이에 준다.
        let byHeight = (size.height - minTopMargin - toolPickerReserve) / compositionHeight

        // 아래로 0.85 — 아이패드가 아이폰보다 작아 보이는 일은 없어야 하지만,
        // **아이폰보다 낮은 화면**에서는 이야기가 다르다.
        // mini 를 눕히면 높이가 744 로 아이폰(874)보다 짧아 아이폰 구성이 통째로 들어가지 않는다.
        // 하한을 1 로 붙들어 두면 모자란 23 을 위아래 어느 한쪽에서 빼야 하는데,
        // 위는 `minTopMargin` 이 지켜 주므로 **아래가 전부 깎였다** —
        // 종이와 도구 막대 사이가 45 에서 22 로 좁아져 둘이 붙어 보였다.
        // 4.5% 줄어드는 것은 눈에 띄지 않지만 막대에 닿는 것은 눈에 띈다.
        //
        // 위로 1.6 — 더 키우면 손이 종이 끝까지 닿지 않는다.
        return min(1.6, max(0.85, min(byWidth, byHeight)))
    }

    /// 타이머를 화면 꼭대기에서 얼마나 내려 붙일지.
    ///
    /// 남는 자리를 아이폰과 같은 비율(위 112 : 아래 252)로 나눠 갖는다.
    private static func countdownTop(in size: CGSize) -> CGFloat {
        guard size.width >= 600 else { return countdownTopInset }
        // 남는 자리를 아이폰과 같은 비율로 나눠 갖되, 위쪽은 `minTopMargin` 아래로 내려가지 않는다.
        let byShare = (size.height - compositionHeight * canvasScale(in: size)) * topShare
        return max(minTopMargin, byShare)
    }

    /// 종이를 화면 정중앙에서 얼마나 올릴지.
    ///
    /// 타이머 자리에서 아래로 `timerToCanvas` 만큼 내려간 곳이 종이 윗변이다.
    /// 그 중심을 화면 중심과 견주어 차이만큼 민다.
    private static func canvasOffset(in size: CGSize) -> CGFloat {
        guard size.width >= 600 else { return canvasCenterOffset }
        let scale = canvasScale(in: size)
        let canvasCenter = countdownTop(in: size) + (timerToCanvas + canvasSizeHeight / 2) * scale
        return canvasCenter - size.height / 2
    }

    /// 키보드에 가리지 않도록 카드를 위로 밀 거리.
    ///
    /// 화면 기준으로 못박아 둔 카드라 SwiftUI 의 자동 회피가 닿지 않는다.
    /// 자동 회피에 맡기면 남는 자리 한가운데로 다시 앉느라 필요 이상으로 올라가
    /// 이번에는 위쪽 툴바에 가렸다. 그래서 모자란 만큼만 직접 민다.
    private func keyboardLift(in size: CGSize) -> CGFloat {
        guard keyboardTop > 0, size.height > 0 else { return 0 }
        let scale = Self.canvasScale(in: size)
        let half = DoodleMetrics.canvasSize.height * scale / 2
        let center = size.height / 2 + Self.canvasOffset(in: size)
        let needed = max(0, center + half - (keyboardTop - Self.keyboardGap))

        // 밀어 올릴 자리가 없으면 밀지 않는다.
        //
        // 넓은 화면에서는 종이가 커진 만큼 위로 갈 자리가 줄어든다.
        // 아이패드를 눕히면 높이 834 에 키보드가 450 가까이 올라와,
        // 제한이 없을 때는 종이가 69 만큼 화면 위로 빠져나가 「To.」 줄이 잘렸다.
        //
        // 아이폰은 제한을 두지 않는다 — 지금까지의 움직임을 그대로 남긴다.
        guard size.width >= 600 else { return needed }
        let room = max(0, center - half - Self.minTopMargin)
        return min(needed, room)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Figma `iPhone 17 - 18` 의 배경. 뽑아 보니 #F2F2F7,
                // 곧 iOS 의 systemGroupedBackground 와 같은 값이다.
                // 값을 박아 두는 대신 시스템 색을 쓰면 대비 설정에도 따라간다.
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                // 타이머는 화면 맨 위에서 잰 자리에 고정한다.
                // 툴바가 단계에 따라 나타났다 사라지는데, 그때마다 안전영역이 달라져
                // 타이머가 위아래로 튀었다. 안전영역을 직접 재서 붙이면 흔들리지 않는다.
                // 갤러리와 같은 라지 타이틀. (20, 70) 에 34pt Bold.
                // 시작을 누르면 그 자리를 툴바가 쓰므로 누르기 전에만 둔다.
                if session.phase == .notStarted {
                    Text("그리기")
                        .font(.system(size: 34, weight: .bold))
                        .kerning(0.4)
                        .foregroundStyle(Color.doodleTitle)
                        .padding(.leading, Self.titleLeadingInset)
                        .padding(.top, Self.titleTopInset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                }

                GeometryReader { proxy in
                    countdown(scale: Self.canvasScale(in: proxy.size))
                        .padding(.top, Self.countdownTop(in: proxy.size))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .ignoresSafeArea()

                VStack {
                    Spacer()
                    if session.phase == .drawing {
                        DrawingToolPicker(session: session)
                            .padding(.bottom, Self.toolPickerBottomInset(in: screenSize))
                    }
                }
                .safeAreaPadding(.all)

                // 키보드가 어디까지 올라왔는지 재는 자.
                // 안전영역을 따르는 빈 뷰라 키보드가 뜨면 아래 끝이 그만큼 올라온다.
                Color.clear
                    .allowsHitTesting(false)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.frame(in: .global).maxY
                    } action: { keyboardTop = $0 }

                // 툴바 바깥에서도 화면 크기를 알아야 해서 따로 재 둔다.
                GeometryReader { proxy in
                    Color.clear
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { screenSize = $0 }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // 캔버스도 화면 한가운데에 못박는다.
                // 단계마다 툴바와 탭바가 생겼다 사라지면서 안전영역이 달라지는데,
                // 그때마다 캔버스가 따라 움직여 초기화를 누르면 자리가 어긋났다.
                GeometryReader { proxy in
                    memoCard
                        // 넓은 화면에서는 종이를 키워 보여준다.
                        //
                        // `canvasSize`(350x390) 는 **저장된 획의 좌표계**라 건드리면 안 된다.
                        // 그래서 크기 자체가 아니라 배율만 올린다 — 안에서 오가는 좌표는 그대로다.
                        .scaleEffect(Self.canvasScale(in: proxy.size))
                        .offset(x: shakeAmount, y: Self.canvasOffset(in: proxy.size) - keyboardLift(in: proxy.size))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.25), value: keyboardTop)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .onTapGesture { focusedField = nil }
            .toolbarVisibility(session.phase == .notStarted ? .visible : .hidden, for: .tabBar)
            .toolbar { toolbarContent }
            // 그리기 단계이고 화면이 앞에 있을 때만 돈다.
            // 조건이 어긋나면 Task 가 취소되어 남은 시간이 그 자리에 멈춘다.
            // 다시 돌아오면 멈춘 지점부터 이어서 잰다.
            .task(id: countdownRuns) {
                guard countdownRuns else { return }
                await session.runCountdown()
            }
            // Figma `iPhone 17 - 16` 의 확인창. 시스템 alert 를 쓴다.
            // 파괴적 동작이 빨갛게, 취소가 제자리에 오는 배치는 시스템이 알아서 잡아준다.
            .alert("처음부터 다시 그릴까요?", isPresented: $showResetAlert) {
                Button("다시 그리기", role: .destructive) {
                    // 시간만 되돌리면 그려둔 획이 그대로 남아 다음 판에 얹힌다.
                    // 처음부터 다시 그리자는 뜻이므로 그림도 함께 비운다.
                    session.reset()
                    peelPhase = 0
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("지금까지 그린 그림이 지워져요.")
            }
        }
    }

    // MARK: - 남은 시간

    @ViewBuilder
    private func countdown(scale: CGFloat) -> some View {
        Group { if session.phase != .memo {
            // 숫자와 게이지가 붙어 있으면 한 덩어리로 뭉쳐 보인다.
            // 사이를 벌려야 남은 초를 읽는 눈과 줄어드는 막대를 보는 눈이 서로 방해하지 않는다.
            VStack(spacing: 16 * scale) {
                Text("\(Int(session.remaining))")
                    .font(.system(size: 25 * scale, weight: .semibold))
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: Int(session.remaining))

                // 예전에는 Slider 였는데, 썸을 숨겨도 트랙 드래그로 시간을 되감을 수 있었다.
                // ProgressView 는 표시 전용이라 그런 조작이 불가능하다.
                ProgressView(value: session.remaining, total: DrawingSession.duration)
                    .progressViewStyle(ThickBarProgressStyle(height: 15 * scale))
                    // 게이지 양 끝을 아래 캔버스의 좌우 끝과 맞춘다.
                    // 여백을 따로 주면 캔버스 크기가 바뀔 때마다 어긋나므로 같은 값을 쓴다.
                    // 캔버스와 같은 배율로 늘린다. 캔버스만 키우면 막대만 짧게 남는다.
                    .frame(width: DoodleMetrics.canvasSize.width * scale)
                    .padding(.top, 20 * scale)
                    .padding(.bottom, 40 * scale)
                    .accessibilityLabel("남은 시간")
                    .accessibilityValue("\(Int(session.remaining))초")
            }
            // 아직 시작을 누르지 않았으면 시간은 흐르지 않는다.
            // 숫자와 게이지를 함께 흐리게 두어, 지금은 세는 중이 아님을 알린다.
            .opacity(session.phase == .drawing ? 1 : 0.35)
            .animation(.easeOut(duration: 0.25), value: session.phase)
        } }
    }

    // MARK: - 메모지

    private var memoCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DoodleMetrics.canvasCornerRadius)
                .fill(.white)
                .frame(width: DoodleMetrics.canvasSize.width, height: DoodleMetrics.canvasSize.height)
                .shadow(color: .black.opacity(0.3), radius: 40, x: 4, y: 4)

            peelCover

            VStack(spacing: 8) {
                Text("Tap to start")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .font(.system(size: 40))
                    .shadow(color: .white.opacity(0.2), radius: 2)
                Text("상대방의 첫인상을 그려보세요")
                    .fontWeight(.regular)
                    .foregroundStyle(.white)
                    .font(.system(size: 16))
                    .padding(.top, 10)
            }
            .opacity(session.phase == .notStarted && peelPhase == 0 ? 1 : 0)
            .allowsHitTesting(false)
            .zIndex(2)

            if session.phase == .drawing {
                DrawingCanvas(session: session)
            }

            if session.phase == .memo {
                memoFields
            }
        }
    }

    /// 탭하면 벗겨지는 포스트잇 커버.
    private var peelCover: some View {
        Image(.memoCover)
            .resizable()
            .frame(width: DoodleMetrics.canvasSize.width, height: DoodleMetrics.canvasSize.height)
            .rotation3DEffect(
                .degrees(peelPhase == 0 ? 0 : (peelPhase == 1 ? -40 : -85)),
                axis: (x: 0.6, y: 1, z: 0),
                anchor: .topTrailing,
                perspective: 0.4
            )
            .rotationEffect(.degrees(peelPhase == 0 ? 0 : (peelPhase == 1 ? 4 : 30)), anchor: .topTrailing)
            .offset(x: peelPhase == 2 ? 500 : 0, y: peelPhase == 2 ? -200 : 0)
            .opacity(session.phase != .notStarted ? 0 : (peelPhase == 2 ? 0 : 1))
            .shadow(radius: 5)
            .zIndex(1)
            .onTapGesture(perform: peelAway)
            .allowsHitTesting(session.phase == .notStarted)
            .accessibilityLabel("탭해서 그리기 시작")
    }

    private var memoFields: some View {
        VStack(spacing: 0) {
            // 위쪽: 이름 입력 영역
            HStack(spacing: 6) {
                Text("To.")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.colorGray.opacity(0.8))
                TextField(text: $recipientName, prompt: Text("이름").foregroundStyle(.black.opacity(0.42))) {
                    EmptyView()
                }
                .font(.system(size: 20))
                .fontWeight(.semibold)
                .submitLabel(.done)
                .focused($focusedField, equals: .name)

                Spacer(minLength: 0)
            }
            .padding(.top, 33.5)
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity)
            // 위 여백이 그대로 먹도록 위쪽에 붙인다.
            // 가운데 정렬이면 여백을 5 줄여도 절반인 2.5 만 움직인다.
            .frame(height: 80, alignment: .top)
            .contentShape(Rectangle())
            .onTapGesture { focusedField = .name }

            // 아래쪽: 첫인상 텍스트 입력 영역
            ZStack(alignment: .bottom) {
                // 카드 뒷면에 남을 글씨와 같은 손글씨체 · 같은 행높이로 쓴다.
                // 쓰는 동안 보이는 글씨와 저장한 뒤에 보이는 글씨가 달라 놀랄 일이 없다.
                //
                // 자리글은 손글씨가 아니라 원래 쓰던 시스템 글꼴 그대로 둔다.
                // 아직 아무것도 안 쓴 자리와 쓴 글을 눈으로 갈라 준다.
                // 글꼴은 카드 뒷면과 같은 손글씨체다. 행높이는 글꼴 기본값을 쓴다.
                //
                // 행높이 44 를 맞추려고 `UITextView` 를 감싼 입력란을 만들어 뒀다가
                // 「받침이 씹힌다」는 말을 듣고 그것을 의심해 걷어냈는데, 오진이었다.
                // 글자는 처음부터 정확했고, 손글씨체가 받침을 제 글자에서 멀리 떨어뜨려
                // 그리는 탓에 「강나강」이 「가낭가」처럼 보였을 뿐이다.
                // 같은 입력란에 시스템 글꼴만 물리면 「강나강」이 제대로 나온다.
                TextField("", text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .multilineTextAlignment(.center)
                    .font(.doodleHandwriting(size: Self.messageFontSize))
                    .foregroundStyle(Color.doodlePrimary)
                    .focused($focusedField, equals: .text)
                    .onChange(of: inputText) { _, newValue in
                        if newValue.count > Self.textLimit {
                            inputText = String(newValue.prefix(Self.textLimit))
                        }
                    }
                // 자리글은 입력란 위에 겹쳐 그린다.
                // `prompt` 로 주면 본문 글꼴을 그대로 물려받아 손글씨가 된다.
                .overlay {
                    if inputText.isEmpty {
                        Text("첫 대화를 건네보세요 :)")
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.42))
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 60)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text("\(inputText.count)/\(Self.textLimit)")
                    .font(.system(size: 17))
                    .foregroundStyle(.colorGray)
                    .opacity(0.5)
                    .fontWeight(.semibold)
                    .padding(.bottom, 20)
            }
            .contentShape(Rectangle())
            .onTapGesture { focusedField = .text }
        }
        .frame(width: DoodleMetrics.canvasSize.width, height: DoodleMetrics.canvasSize.height)
    }

    // MARK: - 툴바

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // 아직 포스트잇을 떼지도 않았으면 되돌릴 것이 없다.
        // 예전에는 흐린 채로 자리를 지켰는데, 누를 수 없는 버튼은 없는 것만 못하다.
        if session.phase != .notStarted {
            ToolbarItem(placement: .topBarLeading) {
                Button("초기화") { showResetAlert = true }
            }
        }

        if session.phase == .drawing && session.hasStartedDrawing {
            ToolbarItem(placement: .topBarTrailing) {
                // 초기화와 같은 유리 버튼으로 둔다.
                // 강조 버튼은 저장 하나로 충분하다.
                Button("다음") {
                    session.beginMemo()
                }
            }
        }

        if session.phase == .memo {
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") { save() }
                    .buttonStyle(.glassProminent)
                    .disabled(!canSave)
            }
        }
    }

    // MARK: - 동작

    private static let textLimit = 30

    /// 한마디 글씨. 카드 뒷면(`PostDetailView`)과 같은 값을 쓴다.
    /// 글꼴이 바뀌면서 40 으로 올랐다.
    private static let messageFontSize: CGFloat = 40
    private static let messageLineHeight: CGFloat = 44

    /// 포스트잇을 벗기고 그리기를 시작한다.
    ///
    /// 예전에는 `DispatchQueue.main.asyncAfter` 로 시간을 재서 다음 단계로 넘어갔다.
    /// 애니메이션 완료 콜백을 쓰면 실제 애니메이션이 끝나는 시점에 맞춰 이어진다.
    private func peelAway() {
        withAnimation(.easeInOut(duration: 0.4)) {
            peelPhase = 1
        } completion: {
            withAnimation(.easeIn(duration: 0.3)) {
                peelPhase = 2
            } completion: {
                session.beginDrawing()
            }
        }
    }

    private func save() {
        // 키보드를 먼저 내린다. 갤러리로 넘어가며 딸려 올라가 있으면 어수선하다.
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )

        guard canSave else {
            triggerShake()
            return
        }
        let newPost = Post(drawingData: session.drawingData, text: inputText, isMine: true)
        newPost.recipientName = recipientName
        modelContext.insert(newPost)

        // 방금 저장한 그림이 놓인 자리를 열어 준다.
        // 갤러리로 보내 놓고 다른 섹션을 보여주면 그림이 사라진 것처럼 보인다.
        gallerySection = GallerySection.drawnByMe.rawValue
        // 갤러리가 방금 저장한 그림 자리로 옮겨 가도록 표시를 켠다.
        showsJustSavedPost = true

        selectedTabIndex = 0

        // 그리기 화면을 비우는 건 갤러리로 완전히 건너간 뒤에 한다.
        // 먼저 비우면 넘어가는 동안 처음으로 돌아간 화면이 한 번 스쳐 지나간다.
        //
        // `withAnimation` 의 완료 콜백을 써 봤지만, 탭 전환은 그 애니메이션을
        // 타지 않아 콜백이 곧바로 불려 소용이 없었다. 전환이 끝날 시간을 직접 준다.
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            resetAll()
        }
    }

    private func resetAll() {
        session.reset()
        inputText = ""
        recipientName = ""
        shakeAmount = 0
        peelPhase = 0
    }

    private func triggerShake() {
        let d = 0.07
        withAnimation(.easeOut(duration: d))              { shakeAmount =  8 }
        withAnimation(.easeInOut(duration: d).delay(d))   { shakeAmount = -8 }
        withAnimation(.easeInOut(duration: d).delay(d*2)) { shakeAmount =  6 }
        withAnimation(.easeInOut(duration: d).delay(d*3)) { shakeAmount = -6 }
        withAnimation(.easeOut(duration: d).delay(d*4))   { shakeAmount =  0 }
    }
}

/// 두께를 정할 수 있는 막대 게이지.
///
/// 기본 `ProgressView` 는 두께를 못 정한다.
/// `scaleEffect` 로 늘리면 양 끝의 둥근 모양까지 눌려 찌그러지므로 직접 그린다.
/// 그러면 어떤 두께에서도 끝이 반듯하게 둥글다.
///
/// `ProgressView` 를 그대로 두고 스타일만 바꾸므로 접근성 값은 계속 읽힌다.
private struct ThickBarProgressStyle: ProgressViewStyle {
    var height: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)

                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: proxy.size.width * (configuration.fractionCompleted ?? 0))
            }
            // 채워진 쪽을 트랙 모양으로 잘라 낸다.
            //
            // `Capsule` 의 곡률 반경은 짧은 변의 절반이다.
            // 남은 시간이 줄어 채워진 폭이 두께보다 작아지면 반경도 폭의 절반으로 함께
            // 작아져, 트랙의 둥근 끝보다 덜 둥글어진다.
            // 그러면 막대 끝이 트랙 밖으로 삐져나와 모서리가 어긋난 것처럼 보인다.
            //
            // 잘라 두면 채워진 쪽이 어떤 폭이든 트랙의 곡률을 넘지 못한다.
            .clipShape(Capsule())
        }
        .frame(height: height)
    }
}

#Preview {
    DrawingPage(selectedTabIndex: .constant(0))
        .modelContainer(LocalDataStore.makePreviewContainer())
}
