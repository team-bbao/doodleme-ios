//
//  DrawingContentView.swift
//  Duddleme
//
//  Created by Jaesung Lee on 8/13/26.
//

import SwiftUI
import PencilKit

struct DrawingContentView: View {
    // MARK: - 데이터 저장
//    @Environment(\.modelContext) private var modelContext
    
    @Binding var selectedTab: TabMenu
    
    /// `true` 면 그리기 시작
    @State private var isTappedToStart: Bool = false
    /// `true` 면 저장 버튼이 보임
    @State private var showsSaveButton: Bool = false
    /// 리셋 알림창
    @State private var showsResetAlert = false
    /// "다음으로"
    @State private var goNext = false
    /// 흔들기 애니메이션 횟수
    @State private var shakeAmount: CGFloat = 0
    /// 저장가능 여부 - 수신자 이름과 메세지 입력이 모두 완료했을 때
    private var canSave: Bool {
        !drawing.recipientName.isEmpty && !drawing.message.isEmpty
    }
    
    // MARK: - 그림 데이터
    @State private var drawing = Drawing() // TODO: remove
    
    @State private var paint = Paint()
    @State private var canvasView = PKCanvasView()
    
    /// 스냅샷 기록이 저장되었는지 여부
    @State private var hasSavedSnapshot = false
    /// 키보드 등장 위치
    @FocusState private var focusedField: FocusField?
    
    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackgroundView()
                
                if !goNext {
                    VStack {
                        DrawingTimer(isStarted: $isTappedToStart)
                        
                        DrawingToolSelector(
                            canvasView: $canvasView,
                            paint: paint
                        )
                        
                        DrawingField(paint: paint, canvasView: $canvasView)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
                
//                Circle()
            }
        }
    }
}

#Preview {
    DrawingContentView(selectedTab: .constant(.drawing))
}
