//
//  PostTransferData.swift
//  DoodleMe
//

import CoreGraphics
import Foundation

/// QR·딥링크로 주고받는 `Post`의 전송 표현.
///
/// QR 코드 용량이 매우 작기 때문에 키 이름을 한 글자로 줄이고,
/// 좌표는 `Int`로 반올림한 뒤 3개 중 1개만 남겨(`stride(by: 3)`) 크기를 줄인다.
struct PostTransferData: Codable {
    var d: [[Int]]   // drawing lines: [x1,y1,x2,y2,...]
    var t: String    // text
    var dt: Double   // date (unix timestamp)
    var p: [[Int]]?  // profile drawing lines
    var n: String?   // sender name

    // Post → JSON 문자열
    static func encode(post: Post, profilePost: Post?, senderName: String?) -> String? {
        let drawingLines = post.lines.map(flatten)
        let profileLines = profilePost?.lines.map(flatten)
        let data = PostTransferData(
            d: drawingLines,
            t: post.text,
            dt: post.createdAt.timeIntervalSince1970,
            p: profileLines,
            n: senderName.flatMap { $0.isEmpty ? nil : $0 }
        )
        guard let jsonData = try? JSONEncoder().encode(data) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }

    // JSON 문자열 → PostTransferData
    static func decode(from string: String) -> PostTransferData? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PostTransferData.self, from: data)
    }

    // Line → flat int 배열 (점 다운샘플링 + 반올림)
    private static func flatten(_ line: Line) -> [Int] {
        stride(from: 0, to: line.points.count, by: 3)
            .map { line.points[$0] }
            .flatMap { [Int($0.x.rounded()), Int($0.y.rounded())] }
    }

    // flat int 배열 → [Line]
    private func toLines(_ arrays: [[Int]]) -> [Line] {
        arrays.map { flat in
            var line = Line()
            stride(from: 0, to: flat.count - 1, by: 2).forEach { i in
                line.points.append(CGPoint(x: flat[i], y: flat[i + 1]))
            }
            return line
        }
    }

    func makeDrawingLines() -> [Line] { toLines(d) }
    func makeProfileLines() -> [Line]? { p.map { toLines($0) } }
}
