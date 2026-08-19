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

        // 바꾼 자리에서 바로 디스크에 남긴다.
        //
        // 자동 저장은 앱이 물러날 때를 기다린다.
        // 그 전에 앱이 강제 종료되면 방금 고른 프로필이 없던 일이 되고,
        // 다시 켰을 때 예전 그림이 돌아와 있다. 받은 그림을 즉시 저장하는 것과 같은 이유다.
        try? save()
    }
}
