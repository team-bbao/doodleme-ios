//
//  BakedLineHeightText.swift
//  DoodleMe
//

import CoreText
import SwiftUI

/// 행높이를 정한 값으로 맞춰 그리되, **그림으로 구울 수 있는** 글.
///
/// `FixedLineHeightText` 는 `UILabel` 을 빌려 쓴다. 화면에서는 멀쩡하지만
/// `ImageRenderer` 는 UIKit 뷰를 굽지 못해 **노란 「그릴 수 없음」 자리로 대체된다.**
/// 내보내기 카드를 구워 보고서야 드러났다 — 화면만 봐서는 알 수 없었다.
///
/// 그래서 UIKit 뷰를 쓰지 않는다.
/// 줄을 직접 나눠 한 줄씩 `Text` 로 그리고 정해진 행높이만큼 자리를 준다.
/// `lineSpacing` 을 쓰지 않는 이유는 그것이 글꼴 기본 행높이에 **더하기만** 하기 때문이다 —
/// 손글씨체는 크기 40 에서 기본 행높이가 49.8 이라 디자인이 정한 44 로 **줄일** 수가 없다.
struct BakedLineHeightText: View {

    let lines: [String]
    let uiFont: UIFont
    /// 한 줄이 차지할 높이. 글꼴 기본값보다 작아도 된다.
    let lineHeight: CGFloat
    let color: Color

    /// - Parameter width: 이 폭에서 넘치면 줄을 나눈다. `nil` 이면 `\n` 에서만 나눈다.
    init(_ text: String,
         font: UIFont,
         lineHeight: CGFloat,
         color: Color,
         width: CGFloat? = nil) {
        self.uiFont = font
        self.lineHeight = lineHeight
        self.color = color

        let paragraphs = text.components(separatedBy: "\n")
        if let width {
            self.lines = paragraphs.flatMap { Self.wrapped($0, font: font, width: width) }
        } else {
            self.lines = paragraphs
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                text(line)
                    .frame(height: lineHeight)
            }
        }
    }

    private func text(_ line: String) -> some View {
        Text(line)
            .font(.custom(uiFont.fontName, size: uiFont.pointSize))
            .foregroundStyle(color)
            .fixedSize()
    }

    /// 주어진 폭에서 줄이 어디서 끊기는지 CoreText 에게 묻는다.
    ///
    /// `Text` 에 `.frame(height:)` 로 한 줄 높이를 못박으면 스스로 줄을 바꾸지 못하고
    /// 한 줄에 우겨넣다가 「...」로 잘린다. 그래서 끊는 자리를 미리 정해 준다.
    ///
    /// `UILabel` 이 아니라 CoreText 를 쓰는 이유는 이것이 **뷰가 아니기** 때문이다 —
    /// `ImageRenderer` 가 굽지 못하는 것은 UIKit **뷰**이지 글자 계산이 아니다.
    /// 주어진 폭에서 몇 줄이 되는지. 글이 담길 상자 높이를 미리 잴 때 쓴다.
    static func lineCount(_ text: String, font: UIFont, width: CGFloat) -> Int {
        text.components(separatedBy: "\n")
            .reduce(0) { $0 + wrapped($1, font: font, width: width).count }
    }

    static func wrapped(_ text: String, font: UIFont, width: CGFloat) -> [String] {
        guard !text.isEmpty else { return [""] }
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let typesetter = CTTypesetterCreateWithAttributedString(attributed)
        let source = text as NSString

        var lines: [String] = []
        var start = 0
        while start < source.length {
            let count = CTTypesetterSuggestLineBreak(typesetter, start, Double(width))
            guard count > 0 else { break }
            let piece = source.substring(with: NSRange(location: start, length: count))
            lines.append(piece.trimmingCharacters(in: .whitespaces))
            start += count
        }
        return lines.isEmpty ? [text] : lines
    }
}
