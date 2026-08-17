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

    // MARK: - 외부 입력 제한
    //
    // 딥링크와 QR은 앱 바깥에서 들어오는, 신뢰할 수 없는 입력이다.
    // 터무니없는 크기의 데이터가 저장소를 채우거나 렌더링을 멈추게 하지 못하도록 상한을 둔다.

    private enum Limit {
        static let lineCount = 500
        static let pointsPerLine = 2_000
        static let totalPoints = 20_000
        static let textLength = 200
        static let nameLength = 40
        /// 캔버스를 크게 벗어난 좌표는 이 범위로 자른다.
        static let coordinate = -2_000...2_000
        /// 1970년 이후 ~ 2096년 이전.
        static let timestamp = 0.0...4_000_000_000.0
    }

    // MARK: - 딥링크

    static let urlScheme = "doodleme"
    private static let importHost = "import"

    /// 공유용 딥링크. QR 코드에 담는 문자열이기도 하다.
    static func makeShareURL(post: Post, profilePost: Post?, senderName: String?) -> URL? {
        guard let json = encode(post: post, profilePost: profilePost, senderName: senderName),
              let jsonData = json.data(using: .utf8)
        else { return nil }

        // base64url 인코딩 (URL 안전 문자로 변환)
        let base64url = jsonData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        var components = URLComponents()
        components.scheme = urlScheme
        components.host = importHost
        components.queryItems = [URLQueryItem(name: "data", value: base64url)]
        return components.url
    }

    /// 수신한 딥링크에서 전송 데이터를 복원한다. 형식이 어긋나거나 크기 제한을 넘으면 `nil`.
    static func decode(deepLink url: URL) -> PostTransferData? {
        guard url.scheme == urlScheme,
              url.host == importHost,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let dataParam = components.queryItems?.first(where: { $0.name == "data" })?.value
        else { return nil }

        // base64url → base64 표준 형식 복원
        var base64 = dataParam
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)

        guard let jsonData = Data(base64Encoded: base64),
              let json = String(data: jsonData, encoding: .utf8)
        else { return nil }

        return decode(from: json)
    }

    // MARK: - JSON

    // Post → JSON 문자열
    static func encode(post: Post, profilePost: Post?, senderName: String?) -> String? {
        let data = PostTransferData(
            d: post.lines.map(flatten),
            t: post.text,
            dt: post.createdAt.timeIntervalSince1970,
            p: profilePost?.lines.map(flatten),
            n: senderName.flatMap { $0.isEmpty ? nil : $0 }
        )
        guard let jsonData = try? JSONEncoder().encode(data) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }

    /// JSON 문자열 → PostTransferData. 크기 제한을 넘는 데이터는 받지 않는다.
    static func decode(from string: String) -> PostTransferData? {
        guard let data = string.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(PostTransferData.self, from: data),
              decoded.isWithinLimits
        else { return nil }
        return decoded
    }

    private var isWithinLimits: Bool {
        let allLines = d + (p ?? [])
        guard d.count <= Limit.lineCount, (p?.count ?? 0) <= Limit.lineCount else { return false }
        // 한 점이 값 2개(x, y)를 차지한다.
        guard allLines.allSatisfy({ $0.count <= Limit.pointsPerLine * 2 }) else { return false }
        guard allLines.reduce(0, { $0 + $1.count }) <= Limit.totalPoints * 2 else { return false }
        guard t.count <= Limit.textLength else { return false }
        guard (n?.count ?? 0) <= Limit.nameLength else { return false }
        guard dt.isFinite, Limit.timestamp.contains(dt) else { return false }
        return true
    }

    // MARK: - 변환

    /// 받은 데이터로 `Post`를 만든다. 딥링크·QR 스캔 양쪽이 이 경로를 함께 쓴다.
    func makePost() -> Post {
        let post = Post(
            lines: makeDrawingLines(),
            text: String(t.prefix(Limit.textLength)),
            isMine: false
        )
        post.createdAt = Date(timeIntervalSince1970: dt)
        post.senderName = if let n, !n.isEmpty {
            String(n.prefix(Limit.nameLength))
        } else {
            Post.unknownSenderName
        }
        post.senderProfileLines = makeProfileLines() ?? []
        return post
    }

    func makeDrawingLines() -> [Line] { toLines(d) }
    func makeProfileLines() -> [Line]? { p.map { toLines($0) } }

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
                line.points.append(
                    CGPoint(x: Self.clampCoordinate(flat[i]), y: Self.clampCoordinate(flat[i + 1]))
                )
            }
            return line
        }
    }

    private static func clampCoordinate(_ value: Int) -> Int {
        min(max(value, Limit.coordinate.lowerBound), Limit.coordinate.upperBound)
    }
}
