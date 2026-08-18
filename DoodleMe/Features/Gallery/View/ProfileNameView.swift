//
//  ProfileNameView.swift
//  DoodleMe
//

import SwiftUI

struct ProfileNameView: View {
    @Binding var profileName: String

    @State private var showingEditor = false
    @State private var draftName = ""

    var body: some View {
        Button {
            draftName = profileName
            showingEditor = true
        } label: {
            Text(profileName.isEmpty ? "이름" : profileName)
                // Figma `iPhone 17 - 1` 의 이름 스타일
                // Figma 는 Semibold 이지만 화면에서 얇아 보여 한 단계 올렸다.
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(profileName.isEmpty ? Color.gray : .doodlePrimary)
                .padding(.top, 17)
        }
        .buttonStyle(.plain)
        .alert("프로필 이름", isPresented: $showingEditor) {
            TextField("이름", text: $draftName)
            Button("저장") {
                let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                profileName = trimmed.isEmpty ? profileName : trimmed
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("프로필에 표시되는 이름을 수정합니다.")
        }
    }
}
