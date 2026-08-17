//
//  Post.swift
//  DoodleMe
//

import Foundation
import SwiftData

/// 첫인상 그림 한 장. 내가 그린 것(`isMine == true`)과 남에게 받은 것을 모두 담는다.
///
/// 그림은 `PKDrawing.dataRepresentation()` 바이너리로 저장한다.
/// `PKDrawing` 으로 꺼내 쓰는 건 `Post+Drawing` 참고.
@Model
class Post {
    var drawingData: Data
    var text: String
    var isMine: Bool
    var createdAt: Date
    var isProfile: Bool = false
    var recipientName: String = ""
    var senderName: String = ""
    var senderProfileDrawingData: Data?

    init(drawingData: Data, text: String, isMine: Bool) {
        self.drawingData = drawingData
        self.text = text
        self.isMine = isMine
        self.createdAt = Date()
    }
}

extension Post {
    /// 보낸 사람 이름을 모를 때 대신 보여주는 이름.
    static let unknownSenderName = "홍길동"

    /// 화면에 표시할 보낸 사람 이름.
    var displaySenderName: String {
        senderName.isEmpty ? Self.unknownSenderName : senderName
    }
}
