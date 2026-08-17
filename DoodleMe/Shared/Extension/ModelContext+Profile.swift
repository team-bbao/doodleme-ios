//
//  ModelContext+Profile.swift
//  DoodleMe
//

import Foundation
import SwiftData

extension ModelContext {
    /// 프로필로 쓰는 그림은 앱 전체에서 하나만 유지한다.
    ///
    /// `isProfile`은 여러 글이 동시에 켤 수 있는 평범한 Bool이라, 규칙을 코드로 강제할 곳이 필요하다.
    /// 프로필을 바꾸는 모든 경로는 이 메서드만 거치도록 한다. `nil`을 넘기면 프로필을 비운다.
    func setProfilePost(_ post: Post?) {
        let descriptor = FetchDescriptor<Post>(predicate: #Predicate { $0.isProfile })
        let currentlyMarked = (try? fetch(descriptor)) ?? []

        for existing in currentlyMarked where existing.persistentModelID != post?.persistentModelID {
            existing.isProfile = false
        }
        post?.isProfile = true
    }
}
