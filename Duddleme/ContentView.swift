//
//  ContentView.swift
//  Duddleme
//
//  Created by Jaesung Lee on 8/13/26.
//

import SwiftUI
import SwiftData

// 앱에서 사용하는 탭 메뉴 케이스
enum TabMenu: Hashable {
    case drawing
    case gallery
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPosts: [Post]
    @State private var importSuccess = false
    @State private var selectedTab: TabMenu = .drawing
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // MARK: 갤러리 탭
            Tab(
                "갤러리",
                systemImage: "square.grid.2x2",
                value: .gallery
            ) {
                Listpage()
            }
            
            // MARK: 드로잉 탭
            Tab(
                "드로잉",
                systemImage: "pencil.tip",
                value: .drawing
            ) {
                DrawingContentView(selectedTab: $selectedTab)
            }
        }
    }
}

#Preview {
    ContentView()
}
