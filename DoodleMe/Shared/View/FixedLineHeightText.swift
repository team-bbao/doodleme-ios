//
//  FixedLineHeightText.swift
//  DoodleMe
//

import SwiftUI
import UIKit

/// 행높이를 정한 값으로 못박아 그리는 글.
///
/// SwiftUI `Text` 로는 행높이를 **줄일** 수 없다.
/// `lineSpacing` 은 글꼴의 기본 행높이에 더하기만 하고,
/// `AttributedString` 에 문단 스타일을 실어 봐도 `Text` 가 무시한다.
/// (둘 다 붙여서 화면을 재 보고 확인했다.)
///
/// 세로 여백이 넉넉한 손글씨체는 기본 행높이가 글자 크기의 두 배를 넘기도 한다.
/// 디자인이 정한 행높이를 지키려면 문단 스타일을 그대로 따르는 `UILabel` 을 빌리는 수밖에 없다.
struct FixedLineHeightText: UIViewRepresentable {

    let text: String
    let font: UIFont
    /// 한 줄이 차지할 높이. 글꼴 기본값보다 작아도 된다.
    let lineHeight: CGFloat
    let color: UIColor

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        // 폭은 SwiftUI 가 정해 주고 높이는 글이 필요한 만큼 쓴다.
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.attributedText = attributedText
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView label: UILabel,
        context: Context
    ) -> CGSize? {
        // 폭을 정해 주지 않으면 한 줄로 쭉 늘어난다. 그 경우는 라벨이 재는 대로 둔다.
        let width = proposal.width ?? .greatestFiniteMagnitude
        return label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }

    private var attributedText: NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight

        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph,
                // 줄 상자를 글꼴 기본값보다 좁히면 글자가 상자 위로 붙어 잘린다.
                // 줄어든 만큼을 나눠 내려 상자 가운데에 오게 한다.
                .baselineOffset: (lineHeight - font.lineHeight) / 4
            ]
        )
    }
}
