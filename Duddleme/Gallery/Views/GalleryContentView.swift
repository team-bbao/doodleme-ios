//
//  GalleryContentView.swift
//  Duddleme
//
//  Created by Jaesung Lee on 8/13/26.
//

import SwiftUI
import SwiftData

struct GalleryContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Post
    @Query private var allPosts: [Post]
    var postsByMe: [Post] {
        allPosts.filter { $0.isMine}
    }
    var postsByOthers: [Post] {
        allPosts.filter { !$0.isMine }
    }
    
    // MARK:
    
    
    var body: some View {
        Text("Gallery")
    }
}
