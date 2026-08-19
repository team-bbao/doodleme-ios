//
//  DoodleMeApp.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/6/26.
//

import SwiftData
import SwiftUI

@main
struct DoodleMeApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(LocalDataStore.makeContainer())
    }
}
