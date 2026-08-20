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
/// **커서가 있는 동안에는 뷰에 손대지 않는다.** 이 파일에서 제일 중요한 규칙이다.
/// 한글은 자모를 모아 한 글자를 만드는 동안 '조합 중' 상태로 있는데,
/// 그때 글이든 글자 모양이든 건드리면 조합이 끊겨 친 글자가 씹힌다.
/// 조합 중만 피하는 것으로는 모자랐다 — 한 글자가 막 완성되고 다음 자모가
/// 시작되는 틈에도 걸린다. 그래서 치는 동안에는 아예 아무것도 쓰지 않는다.
///
/// 글자 수 제한도 밖에서 잘라 되돌려주지 않고 여기서 직접 막는다.
/// 되돌려주는 길이 곧 조합을 깨는 길이기 때문이다.
///
/// 자리글도 여기서 다루지 않는다. 비었을 때 겹쳐 그리는 편이 낫다.
/// 텍스트뷰 안에 넣었더니 지우고 첫 글자를 칠 때 그 글자가 자리글 모양을 물려받았다.
struct FixedLineHeightTextEditor: UIViewRepresentable {

    @Binding var text: String

    let font: UIFont
    /// 한 줄이 차지할 높이. 글꼴 기본값보다 작아도 된다.
    let lineHeight: CGFloat
    let color: UIColor

    /// 최대 글자 수. 넘겨서 칠 수 없게 막는다.
    let characterLimit: Int

    /// 지금 이 입력란에 커서가 있는지. 바깥 상태와 맞물린다.
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

        // 글자 모양은 여기서 한 번만 정한다. 이후로는 다시 씌우지 않는다.
        view.typingAttributes = attributes
        view.attributedText = NSAttributedString(string: text, attributes: attributes)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.isFocused = $isFocused
        context.coordinator.characterLimit = characterLimit
        context.coordinator.attributes = attributes

        // 커서가 있으면 사용자가 치는 중이다. 글에 손대지 않는다.
        // 밖에서 갈아끼우는 일(저장한 뒤 비우기 등)은 커서가 없을 때만 일어난다.
        if !view.isFirstResponder, view.text != text {
            view.attributedText = NSAttributedString(string: text, attributes: attributes)
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
        // 폭은 준 만큼 다 쓴다. 글자 폭으로 잡으면 비었을 때 0 이 되어
        // 누를 자리도, 위에 겹쳐 둔 자리글도 사라진다.
        // 높이만 내용에 맞추되, 비어 있어도 한 줄 자리는 지킨다.
        // 조합 중에는 재지 않고 지난번 값을 그대로 쓴다.
        // 재는 일은 글자 상자를 다시 배치하게 만들고, 그 배치가 조합을 끊는다.
        if view.markedTextRange != nil, let last = context.coordinator.lastSize {
            return last
        }

        let width = proposal.width ?? .greatestFiniteMagnitude
        let fitted = view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let size = CGSize(
            width: proposal.width ?? fitted.width,
            height: max(fitted.height, lineHeight)
        )
        context.coordinator.lastSize = size
        return size
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            isFocused: $isFocused,
            characterLimit: characterLimit,
            attributes: attributes
        )
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
        var characterLimit: Int
        var attributes: [NSAttributedString.Key: Any]
        /// 마지막으로 잰 크기. 조합 중에는 다시 재지 않고 이걸 쓴다.
        var lastSize: CGSize?

        init(
            text: Binding<String>,
            isFocused: Binding<Bool>,
            characterLimit: Int,
            attributes: [NSAttributedString.Key: Any]
        ) {
            self.text = text
            self.isFocused = isFocused
            self.characterLimit = characterLimit
            self.attributes = attributes
        }

        /// 글자 수를 넘기는 입력을 미리 막는다.
        ///
        /// 조합 중일 때는 통과시킨다. 여기서 막으면 자모가 붙다 말고 끊긴다.
        /// 조합이 끝나 넘치면 그때 `textViewDidChange` 가 잘라낸다.
        func textView(
            _ view: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText replacement: String
        ) -> Bool {
            guard view.markedTextRange == nil, !replacement.isEmpty else { return true }

            let after = (view.text as NSString).replacingCharacters(in: range, with: replacement)
            return after.count <= characterLimit
        }

        func textViewDidBeginEditing(_ view: UITextView) {
            isFocused.wrappedValue = true
        }

        func textViewDidEndEditing(_ view: UITextView) {
            text.wrappedValue = view.text
            isFocused.wrappedValue = false
        }

        func textViewDidChange(_ view: UITextView) {
            // 조합 중이면 아무것도 하지 않는다.
            //
            // 받침이 붙는 글자는 조합이 여러 번에 걸쳐 이어진다 — 「ㄱ → 가 → 각」.
            // 그동안 값을 바깥으로 흘리면 SwiftUI 가 매번 다시 그리고,
            // 그 다시 그리기가 조합을 건드려 받침이 통째로 날아간다.
            // 조합이 끝나면 이 메서드가 한 번 더 불리므로 그때 한꺼번에 넘긴다.
            guard view.markedTextRange == nil else {
                // 다만 '비었는지 아닌지'가 뒤집히는 순간만은 조합 중에도 알린다.
                // 저장 버튼이 그 값으로 켜지고 꺼지는데, 한 글자만 치고 저장하려 하면
                // 그 글자가 아직 조합 중이라 버튼이 꺼진 채였다.
                // 글 하나를 쓰는 동안 이 뒤집힘은 한 번뿐이라 조합을 흔들지 않는다.
                if text.wrappedValue.isEmpty != view.text.isEmpty {
                    text.wrappedValue = view.text
                }
                return
            }

            // 자모가 모여 글자가 되면서 한도를 넘길 수 있다.
            if view.text.count > characterLimit {
                let cut = String(view.text.prefix(characterLimit))
                view.attributedText = NSAttributedString(string: cut, attributes: attributes)
            }
            text.wrappedValue = view.text
        }
    }
}
