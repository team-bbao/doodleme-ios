//
//  ProfileNameView.swift
//  DoodleMe
//

import SwiftUI

struct ProfileNameView: View {
    @Binding var profileName: String

    /// 넓은 화면에서 얼마나 키울지. 아이폰에서는 1 이라 지금까지와 같다.
    var scale: CGFloat = 1

    /// Figma 이름 글자. `17 - 25`(222:1188) · `17 - 36`(424:1216) 이 20 · 자간 0.4 다.
    private static let nameSize: CGFloat = 20
    private static let nameTracking: CGFloat = 0.4

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
                // Figma `iPhone 17 - 25`(222:1188) · `17 - 36`(424:1216) 의 이름 스타일 —
                // SF Pro **Semibold 20**, 자간 **+0.4**, `#424242`.
                //
                // 한때 「화면에서 얇아 보인다」는 이유로 Bold 로 한 단계 올려 두었는데,
                // 도안이 정한 무게가 Semibold 라 되돌렸다. 자간도 빠져 있어 함께 넣는다.
                //
                // `17 - 13` 은 25 짜리인데 그건 옛 프레임이다 — 「닉네임 25 -> 20」 으로
                // 줄이라는 지시를 받아 20 으로 맞췄고, 최신 프레임도 20 이다.
                .font(.system(size: Self.nameSize * scale, weight: .semibold))
                .tracking(Self.nameTracking * scale)
                .foregroundStyle(profileName.isEmpty ? Color.gray : .doodlePrimary)
                // 프로필 원 아래로 띄우는 간격. Figma 는 원 밑변에서 이름 상자까지 7.5.
                // 원이 `offset(y: 5)` 로 내려가 있으므로 그만큼 더한다.
                .padding(.top, 12.5 * scale)
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
