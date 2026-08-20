//
//  ProfileNameView.swift
//  DoodleMe
//

import SwiftUI

struct ProfileNameView: View {
    @Binding var profileName: String

    /// 이름 최대 글자 수. 세그먼트 위에 한 줄로 들어가야 해서 너무 길면 곤란하다.
    private static let nameLimit = 15

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
                // 저장할 때만 자르면 사용자는 넘치게 쓴 뒤에야 잘린 걸 안다.
                // 입력하는 동안 막아서 지금 몇 글자까지 되는지 바로 알게 한다.
                .onChange(of: draftName) { _, newValue in
                    if newValue.count > Self.nameLimit {
                        draftName = String(newValue.prefix(Self.nameLimit))
                    }
                }
            Button("저장") {
                // 다 지우고 저장하면 비운 대로 둔다.
                // 예전에는 빈 이름을 물리치고 옛 이름을 되살렸는데,
                // 지운 사람 입장에서는 저장이 먹지 않은 것처럼 보였다.
                // 비면 위에서 회색 「이름」이 대신 뜨고,
                // 상대에게 보일 이름은 `MultipeerSession` 이 「doodle.me 사용자」로 채운다.
                profileName = String(
                    draftName
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .prefix(Self.nameLimit)
                )
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("프로필에 표시되는 이름을 수정합니다. (최대 \(Self.nameLimit)자)")
        }
    }
}
