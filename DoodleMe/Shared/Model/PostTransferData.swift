//
//  PostTransferData.swift
//  DoodleMe
//

import Foundation

/// 멀티피어로 주고받는 `Post` 의 전송 표현.
///
/// QR 시절에는 용량 때문에 좌표를 솎아내고 키 이름을 한 글자로 줄여야 했지만,
/// 멀티피어는 그런 제약이 없어 `PKDrawing` 바이너리를 그대로 보낸다.
struct PostTransferData: Codable {
    var drawing: Data
    var text: String
    var createdAt: Date
    var senderName: String?
    var senderProfileDrawing: Data?

    // MARK: - 외부 입력 제한
    //
    // 네트워크로 들어오는, 신뢰할 수 없는 입력이다.
    // 터무니없는 크기의 데이터가 저장소를 채우지 못하도록 상한을 둔다.

    private enum Limit {
        static let drawingBytes = 4 * 1024 * 1024   // 4MB
        static let textLength = 200
        static let nameLength = 40
        /// 1970년 이후 ~ 2096년 이전.
        static let timestamp = 0.0...4_000_000_000.0
    }

    // MARK: - 변환

    init(post: Post, senderName: String?, profileDrawingData: Data?) {
        self.drawing = post.drawingData
        self.text = post.text
        self.createdAt = post.createdAt
        self.senderName = senderName.flatMap { $0.isEmpty ? nil : $0 }
        self.senderProfileDrawing = profileDrawingData
    }

    /// 받은 데이터로 `Post` 를 만든다. 텍스트·이름은 제한 길이로 자른다.
    func makePost() -> Post {
        let post = Post(
            drawingData: drawing,
            text: String(text.prefix(Limit.textLength)),
            isMine: false
        )
        post.createdAt = createdAt
        post.senderName = if let senderName, !senderName.isEmpty {
            String(senderName.prefix(Limit.nameLength))
        } else {
            Post.unknownSenderName
        }
        post.senderProfileDrawingData = senderProfileDrawing
        return post
    }

    // MARK: - 직렬화

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// 받은 바이트를 해석한다. 형식이 어긋나거나 크기 제한을 넘으면 `nil`.
    static func decode(from data: Data) -> PostTransferData? {
        guard let decoded = try? JSONDecoder().decode(PostTransferData.self, from: data),
              decoded.isWithinLimits
        else { return nil }
        return decoded
    }

    private var isWithinLimits: Bool {
        guard drawing.count <= Limit.drawingBytes else { return false }
        guard (senderProfileDrawing?.count ?? 0) <= Limit.drawingBytes else { return false }
        guard text.count <= Limit.textLength else { return false }
        guard (senderName?.count ?? 0) <= Limit.nameLength else { return false }
        guard Limit.timestamp.contains(createdAt.timeIntervalSince1970) else { return false }
        return true
    }
}
