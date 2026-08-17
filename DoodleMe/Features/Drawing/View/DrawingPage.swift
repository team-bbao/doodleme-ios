//
//  DrawingPage.swift
//  DoodleMe
//

import SwiftUI
import Combine
import SwiftData

struct DrawingPage: View {

    @Binding var selectedTabIndex: Int
    
    @State private var selectedTab = 0
    @State private var TapToStart: Bool = false
    @State private var showSaveButton: Bool = false
    @State private var timeRemaining: Double = 30
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    @State private var lines: [Line] = []
    @State private var redoStack: [[Line]] = []
    @State private var undoStack: [[Line]] = []
    @State private var hasSavedSnapshot = false
    @State private var inputText = ""
    @State private var recipientName = ""
    @State private var shakeAmount: CGFloat = 0
    @FocusState private var focusedField: DrawingFocusField?
    @State private var showResetAlert = false
    @State private var goNext = false
    @State private var peelPhase: Int = 0
    
    @Environment(\.modelContext) private var modelContext
    
    var canSave: Bool { !recipientName.isEmpty && !inputText.isEmpty }
    
    var body: some View {
        NavigationStack{
            ZStack {
                GeometryReader { proxy in
                    Image("papertype1")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width)
                        .clipped()
                        .ignoresSafeArea()
                }
                
                
                VStack{
                    if !goNext {
                        VStack(spacing: 4) {
                            Text("\(Int(timeRemaining))")
                                .font(.system(size: 25, weight: .semibold))
                                .contentTransition(.numericText(countsDown: true))
                                .animation(.default, value: Int(timeRemaining))
                                .opacity(TapToStart ? 1 : 0.35)
                            
                            Slider(value: $timeRemaining, in: 0...30)
                                .onReceive(timer) { _ in
                                    if TapToStart && timeRemaining > 0 {
                                        timeRemaining -= 0.05
                                    }
                                }
                                .sliderThumbVisibility(.hidden)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 40)
                        }
                    }
                }
                .offset(y: -320)
                
                VStack {
                    Spacer()
                    DrawingToolPicker(
                        selectedTab: $selectedTab,
                        lines: $lines,
                        redoStack: $redoStack,
                        undoStack: $undoStack,
                        goNext: $goNext
                    )
                    .padding(.bottom, 90)
                }
                .safeAreaPadding(.all)
                
                ZStack{
                    
                    RoundedRectangle(cornerRadius: 50)
                        .fill(.white)
                        .frame(width: 350, height: 390)
                        .shadow(color: .black.opacity(0.3), radius: 40, x: 4, y: 4)
                    
                    //포스트잇 벗겨지는 동작
                    Image("메모지.black")
                        .resizable()
                        .frame(width: 350, height: 390)
                        .rotation3DEffect(
                            .degrees(peelPhase == 0 ? 0 : (peelPhase == 1 ? -40 : -85)),
                            axis: (x: 0.6, y: 1, z: 0),
                            anchor: .topTrailing,
                            perspective: 0.4
                        )
                        .rotationEffect(.degrees(peelPhase == 0 ? 0 : (peelPhase == 1 ? 4 : 30)), anchor: .topTrailing)
                        .offset(x: peelPhase == 2 ? 500 : 0, y: peelPhase == 2 ? -200 : 0)
                        .opacity(TapToStart ? 0 : (peelPhase == 2 ? 0 : 1))
                        .shadow(radius: 5)
                        .zIndex(1)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.4)) { peelPhase = 1 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                withAnimation(.easeIn(duration: 0.3)) { peelPhase = 2 }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    TapToStart = true
                                }
                            }
                        }
                        .allowsHitTesting(!TapToStart)
                    
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
                    .opacity(TapToStart ? 0 : (peelPhase == 0 ? 1 : 0))
                    .allowsHitTesting(false)
                    .zIndex(2)
                    
                    if TapToStart && !goNext {
                        DrawingCanvas(
                            selectedTab: $selectedTab,
                            lines: $lines,
                            redoStack: $redoStack,
                            undoStack: $undoStack,
                            hasSavedSnapshot: $hasSavedSnapshot
                        )
                    }
                    
                    if goNext {
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
                                Spacer()
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
                                        if newValue.count > 30 {
                                            inputText = String(newValue.prefix(30))
                                        }
                                    }
                                
                                Text("\(inputText.count)/30")
                                    .font(.system(size: 17))
                                    .foregroundStyle(.colorGray)
                                    .opacity(0.5)
                                    .fontWeight(.semibold)
                                    .padding(.bottom, 20)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { focusedField = .text }
                        }
                        .frame(width: 350, height: 390)
                    }
                }
                .offset(x: shakeAmount, y: -40)
                
            }
            .ignoresSafeArea(edges: .bottom)
            .onTapGesture { focusedField = nil }
            .toolbarVisibility(TapToStart ? .hidden : .visible, for: .tabBar)
            .toolbar{
                if !goNext {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("초기화") {
                            timeRemaining = 30
                            TapToStart = false
                            peelPhase = 0
                        }
                        .disabled(!TapToStart)
                        
                    }
                }
                if timeRemaining <= 29.9 && !goNext {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("다음") {
                            goNext = true
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
                
                if goNext {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("초기화") {
                            showResetAlert = true
                        }
                        .alert("정말 리셋하시겠습니까?", isPresented: $showResetAlert) {
                            Button("예", role: .destructive) {
                                resetAll()
                            }
                            Button("아니오", role: .cancel) { }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("저장") {
                            guard canSave else {
                                triggerShake()
                                return
                            }
                            let newPost = Post(lines: lines, text: inputText, isMine: true)
                            newPost.recipientName = recipientName
                            modelContext.insert(newPost)
                            resetAll()
                            selectedTabIndex = 0
                        }
                        .opacity(canSave ? 1.0 : 0.4)
                    }
                }
                
            }
        }
    }
    func resetAll() {
        selectedTab = 0
        TapToStart = false
        timeRemaining = 30
        lines = []
        redoStack = []
        undoStack = []
        hasSavedSnapshot = false
        goNext = false
        inputText = ""
        recipientName = ""
        shakeAmount = 0
        peelPhase = 0
    }
    
    func triggerShake() {
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


//"30초동안 상대방의 첫인상 그림을 그려주세요"
