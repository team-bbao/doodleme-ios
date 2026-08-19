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

    @State private var inputText = ""
    @State private var recipientName = ""
    @State private var shakeAmount: CGFloat = 0
    @State private var showResetAlert = false
    /// 포스트잇이 벗겨지는 연출 단계. 화면 연출 전용이라 세션 모델에 두지 않는다.
    @State private var peelPhase: Int = 0
    @FocusState private var focusedField: DrawingFocusField?
    /// 키보드가 가리기 시작하는 높이. 키보드가 없으면 화면 맨 아래와 같다.
    @State private var keyboardTop: CGFloat = 0

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

    /// 캔버스를 화면 정중앙에서 얼마나 올릴지.
    /// 아래쪽 도구 막대와 탭바가 앉을 자리를 남기려고 위로 당겨 둔다.
    private static let canvasCenterOffset: CGFloat = -10

    /// 카드와 키보드 사이에 남길 틈.
    private static let keyboardGap: CGFloat = 12

    /// 키보드에 가리지 않도록 카드를 위로 밀 거리.
    ///
    /// 화면 기준으로 못박아 둔 카드라 SwiftUI 의 자동 회피가 닿지 않는다.
    /// 자동 회피에 맡기면 남는 자리 한가운데로 다시 앉느라 필요 이상으로 올라가
    /// 이번에는 위쪽 툴바에 가렸다. 그래서 모자란 만큼만 직접 민다.
    private func keyboardLift(screenHeight: CGFloat) -> CGFloat {
        guard keyboardTop > 0, screenHeight > 0 else { return 0 }
        let cardBottom = screenHeight / 2 + Self.canvasCenterOffset + DoodleMetrics.canvasSize.height / 2
        return max(0, cardBottom - (keyboardTop - Self.keyboardGap))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                // 타이머는 화면 맨 위에서 잰 자리에 고정한다.
                // 툴바가 단계에 따라 나타났다 사라지는데, 그때마다 안전영역이 달라져
                // 타이머가 위아래로 튀었다. 안전영역을 직접 재서 붙이면 흔들리지 않는다.
                countdown
                    .padding(.top, Self.countdownTopInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    if session.phase == .drawing {
                        DrawingToolPicker(session: session)
                            .padding(.bottom, 90)
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

                // 캔버스도 화면 한가운데에 못박는다.
                // 단계마다 툴바와 탭바가 생겼다 사라지면서 안전영역이 달라지는데,
                // 그때마다 캔버스가 따라 움직여 초기화를 누르면 자리가 어긋났다.
                GeometryReader { proxy in
                    memoCard
                        .offset(x: shakeAmount, y: Self.canvasCenterOffset - keyboardLift(screenHeight: proxy.size.height))
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
    private var countdown: some View {
        if session.phase != .memo {
            // 숫자와 게이지가 붙어 있으면 한 덩어리로 뭉쳐 보인다.
            // 사이를 벌려야 남은 초를 읽는 눈과 줄어드는 막대를 보는 눈이 서로 방해하지 않는다.
            VStack(spacing: 16) {
                Text("\(Int(session.remaining))")
                    .font(.system(size: 25, weight: .semibold))
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: Int(session.remaining))
                    .opacity(session.phase == .drawing ? 1 : 0.35)

                // 예전에는 Slider 였는데, 썸을 숨겨도 트랙 드래그로 시간을 되감을 수 있었다.
                // ProgressView 는 표시 전용이라 그런 조작이 불가능하다.
                ProgressView(value: session.remaining, total: DrawingSession.duration)
                    .progressViewStyle(ThickBarProgressStyle(height: 15))
                    // 게이지 양 끝을 아래 캔버스의 좌우 끝과 맞춘다.
                    // 여백을 따로 주면 캔버스 크기가 바뀔 때마다 어긋나므로 같은 값을 쓴다.
                    .frame(width: DoodleMetrics.canvasSize.width)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                    .accessibilityLabel("남은 시간")
                    .accessibilityValue("\(Int(session.remaining))초")
            }
        }
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
            .padding(.top, 35)
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .contentShape(Rectangle())
            .onTapGesture { focusedField = .name }

            // 아래쪽: 첫인상 텍스트 입력 영역
            ZStack(alignment: .bottom) {
                TextField("첫 대화를 건네보세요 :)", text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 25, weight: .semibold))
                    .padding(.horizontal, 30)
                    .padding(.bottom, 60)
                    .focused($focusedField, equals: .text)
                    .lineSpacing(15)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: inputText) { _, newValue in
                        if newValue.count > Self.textLimit {
                            inputText = String(newValue.prefix(Self.textLimit))
                        }
                    }

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
                Button("다음") {
                    session.beginMemo()
                }
                .buttonStyle(.glassProminent)
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
        guard canSave else {
            triggerShake()
            return
        }
        let newPost = Post(drawingData: session.drawingData, text: inputText, isMine: true)
        newPost.recipientName = recipientName
        modelContext.insert(newPost)
        resetAll()

        // 방금 저장한 그림이 놓인 자리를 열어 준다.
        // 갤러리로 보내 놓고 다른 섹션을 보여주면 그림이 사라진 것처럼 보인다.
        gallerySection = GallerySection.drawnByMe.rawValue
        selectedTabIndex = 0
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
        }
        .frame(height: height)
    }
}

#Preview {
    DrawingPage(selectedTabIndex: .constant(0))
        .modelContainer(LocalDataStore.makePreviewContainer())
}
