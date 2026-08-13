//
//  DrawingCanvasView.swift
//  Duddleme
//
//  Created by Jaesung Lee on 8/13/26.
//

import SwiftUI

struct DrawingCanvasView: View {
    @State private var peelPhase: Int = 0
    @Bindable var drawing: Drawing
    @Bindable var paint: Paint
    
    @Binding var isTappedToStart: Bool
    @Binding var goNext: Bool
    /// 키보드 등장 위치
    @FocusState private var focusedField: FocusField?
    /// 흔들기 애니메이션 횟수
    @State private var shakeAmount: CGFloat = 0
    
    var body: some View {
        ZStack{
            RoundedRectangle(cornerRadius: 50)
                .fill(.white)
                .frame(width: 350, height: 350)
                .shadow(color: .black.opacity(0.3), radius: 40, x: 4, y: 4)
            
            //포스트잇 벗겨지는 동작
            Image("메모지.black")
                .resizable()
                .frame(width: 350, height: 350)
                .rotation3DEffect(
                    .degrees(peelPhase == 0 ? 0 : (peelPhase == 1 ? -40 : -85)),
                    axis: (x: 0.6, y: 1, z: 0),
                    anchor: .topTrailing,
                    perspective: 0.4
                )
                .rotationEffect(.degrees(peelPhase == 0 ? 0 : (peelPhase == 1 ? 4 : 30)), anchor: .topTrailing)
                .offset(x: peelPhase == 2 ? 500 : 0, y: peelPhase == 2 ? -200 : 0)
                .opacity(isTappedToStart ? 0 : (peelPhase == 2 ? 0 : 1))
                .shadow(radius: 5)
                .zIndex(1)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.4)) { peelPhase = 1 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.easeIn(duration: 0.3)) { peelPhase = 2 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            isTappedToStart = true
                        }
                    }
                }
                .allowsHitTesting(!isTappedToStart)

            VStack(spacing: 8) {
                Text("Tab to Start")
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
            .opacity(isTappedToStart ? 0 : (peelPhase == 0 ? 1 : 0))
            .allowsHitTesting(false)
            .zIndex(2)
            
            if isTappedToStart {
                if !goNext {
//                    DrawingField(paint: paint)
                }
            }
            if goNext {
                VStack(spacing: 0) {
                    // 위쪽: 이름 입력 영역
                    HStack(spacing: 6) {
                        Text("To.")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.colorGray.opacity(0.8))
                        TextField("이름", text: $drawing.recipientName)
                            .font(.system(size: 18))
                            .fontWeight(.semibold)
                            .submitLabel(.done)
                            .focused($focusedField, equals: .name)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .contentShape(Rectangle())
                    .onTapGesture { focusedField = .name }

                    // 아래쪽: 첫인상 텍스트 입력 영역
                    ZStack(alignment: .bottom) {
                        TextField("첫 대화를 건네보세요 :)", text: $drawing.message, axis: .vertical)
                            .lineLimit(1...5)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 25, weight: .semibold))
                            .padding(.horizontal, 30)
                            .padding(.bottom, 60)
                            .focused($focusedField, equals: .text)
                            .lineSpacing(15)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onChange(of: drawing.message) { _, newValue in
                                if newValue.count > 30 {
                                    drawing.message = String(newValue.prefix(30))
                                }
                            }

                        Text("\(drawing.message.count)/30")
                            .font(.system(size: 17))
                            .foregroundStyle(.colorGray)
                            .opacity(0.4)
                            .fontWeight(.semibold)
                            .padding(.bottom, 15)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { focusedField = .text }
                }
                .frame(width: 350, height: 350)
            }
    }
        .offset(x: shakeAmount, y: -30)
    }
}
