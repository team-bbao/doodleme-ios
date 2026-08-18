//
//  DrawingPage.swift
//  DoodleMe
//

import SwiftData
import SwiftUI

struct DrawingPage: View {

    @Binding var selectedTabIndex: Int

    @State private var session = DrawingSession()

    @State private var inputText = ""
    @State private var recipientName = ""
    @State private var shakeAmount: CGFloat = 0
    @State private var showResetAlert = false
    /// 포스트잇이 벗겨지는 연출 단계. 화면 연출 전용이라 세션 모델에 두지 않는다.
    @State private var peelPhase: Int = 0
    @FocusState private var focusedField: DrawingFocusField?

    @Environment(\.modelContext) private var modelContext

    private var canSave: Bool { !recipientName.isEmpty && !inputText.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                GeometryReader { proxy in
                    Image(.papertype1)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width)
                        .clipped()
                        .ignoresSafeArea()
                }

                countdown
                    .offset(y: -320)

                VStack {
                    Spacer()
                    if session.phase == .drawing {
                        DrawingToolPicker(session: session)
                            .padding(.bottom, 90)
                    }
                }
                .safeAreaPadding(.all)

                memoCard
                    .offset(x: shakeAmount, y: -40)
            }
            .ignoresSafeArea(edges: .bottom)
            .onTapGesture { focusedField = nil }
            .toolbarVisibility(session.phase == .notStarted ? .visible : .hidden, for: .tabBar)
            .toolbar { toolbarContent }
            // 카운트다운은 그리기 단계에서만 돈다. 단계가 바뀌면 Task가 취소되어 자동으로 멈춘다.
            .task(id: session.phase) {
                guard session.phase == .drawing else { return }
                await session.runCountdown()
            }
        }
    }

    // MARK: - 남은 시간

    @ViewBuilder
    private var countdown: some View {
        if session.phase != .memo {
            VStack(spacing: 4) {
                Text("\(Int(session.remaining))")
                    .font(.system(size: 25, weight: .semibold))
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: Int(session.remaining))
                    .opacity(session.phase == .drawing ? 1 : 0.35)

                // 예전에는 Slider 였는데, 썸을 숨겨도 트랙 드래그로 시간을 되감을 수 있었다.
                // ProgressView 는 표시 전용이라 그런 조작이 불가능하다.
                ProgressView(value: session.remaining, total: DrawingSession.duration)
                    .tint(.accentColor)
                    .padding(.horizontal, 20)
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
                    .foregroundColor(.white)
                    .font(.system(size: 40))
                    .shadow(color: .white.opacity(0.2), radius: 2)
                Text("상대방의 첫인상을 그려보세요")
                    .fontWeight(.regular)
                    .foregroundColor(.white)
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
                // 입력한 이름만큼만 차지하게 해야 "님에게" 가 바로 옆에 붙는다.
                .fixedSize(horizontal: true, vertical: false)

                // 카드 뒷면과 같은 말투로 맞춘다.
                Text("님에게")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.doodleSecondary)

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
        if session.phase != .memo {
            ToolbarItem(placement: .topBarLeading) {
                Button("초기화") {
                    session.restartTimer()
                    peelPhase = 0
                }
                .disabled(session.phase != .drawing)
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
            ToolbarItem(placement: .topBarLeading) {
                Button("초기화") {
                    showResetAlert = true
                }
                .alert("정말 리셋하시겠습니까?", isPresented: $showResetAlert) {
                    Button("예", role: .destructive) { resetAll() }
                    Button("아니오", role: .cancel) { }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") { save() }
                    .opacity(canSave ? 1.0 : 0.4)
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

#Preview {
    DrawingPage(selectedTabIndex: .constant(0))
        .modelContainer(LocalDataStore.makePreviewContainer())
}
