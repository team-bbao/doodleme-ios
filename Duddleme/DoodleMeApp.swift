//
//  DoodleMeApp.swift
//  Duddleme
//
//  Created by Jaesung Lee on 8/13/26.
//

import SwiftUI
import SwiftData // 데이터 저장을 위함

//@main
struct DoodleMeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Post를 앱에 저장
        .modelContainer(for: Post.self)
    }
}
