//
//  FixedLineHeightTextEditor.swift
//  DoodleMe
//

import SwiftUI
import UIKit

/// 행높이를 정한 값으로 못박고 쓸 수 있는 입력란.
///
/// `FixedLineHeightText` 의 편집 가능한 짝이다.
/// 사연은 같다 — SwiftUI 로는 행높이를 **줄일** 수 없어 UIKit 을 빌린다.
/// 손글씨체는 세로 여백이 넉넉해 30pt 에서 기본 행높이가 73 이나 되는데,
/// 디자인이 정한 44 로 맞추려면 문단 스타일을 그대로 따르는 `UITextView` 가 필요하다.
///
/// 자리글은 여기서 다루지 않는다. 비었을 때 겹쳐 그리는 편이 낫다.
/// 자리글을 텍스트뷰 안에 넣어 봤더니, 지우고 첫 글자를 칠 때
/// 그 글자가 자리글 모양을 물려받아 회색 시스템 글꼴로 찍혔다.
/// 텍스트뷰가 들고 있는 글은 늘 본문 하나뿐이어야 그런 일이 없다.
struct FixedLineHeightTextEditor: UIViewRepresentable {

    @Binding var text: String

    let font: UIFont
    /// 한 줄이 차지할 높이. 글꼴 기본값보다 작아도 된다.
    let lineHeight: CGFloat
    let color: UIColor

    /// 지금 이 입력란에 커서가 있는지. SwiftUI `@FocusState` 와 맞물린다.
    @Binding var isFocused: Bool

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        // 자체 여백을 모두 걷어낸다. 자리는 SwiftUI 쪽 padding 이 잡는다.
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.isScrollEnabled = false
        view.tintColor = color
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.isFocused = $isFocused

        // 한글은 자모를 모아 한 글자를 만드는 동안 '조합 중' 상태로 있는다.
        // 그 사이에 글이나 글자 모양에 손대면 조합이 끊겨 친 글자가 씹힌다.
        // 조합이 끝날 때까지는 아무것도 건드리지 않는다.
        if view.markedTextRange == nil {
            // 치는 동안에는 글을 다시 넣지 않는다. 커서가 끝으로 튄다.
            if view.text != text {
                view.attributedText = NSAttributedString(string: text, attributes: attributes)
            }
            // 다음에 칠 글자도 같은 모양이어야 한다.
            view.typingAttributes = attributes
        }

        if isFocused, !view.isFirstResponder {
            view.becomeFirstResponder()
        } else if !isFocused, view.isFirstResponder {
            view.resignFirstResponder()
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView view: UITextView,
        context: Context
    ) -> CGSize? {
        // 높이를 내용만큼만 쓴다. 그래야 바깥에서 세로 가운데에 놓을 수 있다.
        // 그냥 두면 준 자리를 다 차지해 글이 위쪽에 붙는다.
        let width = proposal.width ?? .greatestFiniteMagnitude
        let fitted = view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        // 폭은 준 만큼 다 쓴다. 글자 폭으로 잡으면 비었을 때 0 이 되어
        // 누를 자리도 사라지고 위에 겹쳐 둔 자리글까지 잘린다.
        // 높이만 내용에 맞추되, 비어 있어도 한 줄 자리는 지킨다.
        return CGSize(width: proposal.width ?? fitted.width, height: max(fitted.height, lineHeight))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }

    /// 본문 글자 모양. 텍스트뷰가 그리는 글은 전부 이 하나를 쓴다.
    private var attributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight

        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
            // 줄 상자를 글꼴 기본값보다 좁히면 글자가 상자 위로 붙어 잘린다.
            // 줄어든 만큼을 나눠 내려 상자 가운데에 오게 한다.
            .baselineOffset: (lineHeight - font.lineHeight) / 4,
        ]
    }

    // MARK: - 주고받기

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var isFocused: Binding<Bool>

        init(text: Binding<String>, isFocused: Binding<Bool>) {
            self.text = text
            self.isFocused = isFocused
        }

        func textViewDidBeginEditing(_ view: UITextView) {
            isFocused.wrappedValue = true
        }

        func textViewDidEndEditing(_ view: UITextView) {
            // 조합이 끝나며 글자가 바뀌었을 수 있다. 마지막으로 한 번 맞춘다.
            text.wrappedValue = view.text
            isFocused.wrappedValue = false
        }

        func textViewDidChange(_ view: UITextView) {
            // 조합 중인 글자도 그대로 내보낸다. 글자 수 세기가 한 글자 늦지 않고,
            // 조합이 끝나기 전에 저장을 눌러도 마지막 글자를 잃지 않는다.
            //
            // 값이 되돌아와도 `updateUIView` 가 조합 중에는 손대지 않으므로 안전하다.
            text.wrappedValue = view.text
        }
    }
}
