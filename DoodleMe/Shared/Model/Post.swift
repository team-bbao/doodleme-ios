//
//  Post.swift
//  DoodleMe
//

import Foundation
import SwiftData

/// 첫인상 그림 한 장. 내가 그린 것(`isMine == true`)과 남에게 받은 것을 모두 담는다.
@Model
class Post {
    var lines: [Line]
    var text: String
    var isMine: Bool
    var createdAt: Date
    var isProfile: Bool = false
    var recipientName: String = ""
    var senderName: String = ""
    var senderProfileLines: [Line] = []

    init(lines: [Line], text: String, isMine: Bool) {
        self.lines = lines
        self.text = text
        self.isMine = isMine
        self.createdAt = Date()
    }
}
