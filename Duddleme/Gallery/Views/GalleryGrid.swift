//
//  GalleryGrid.swift
//  Duddleme
//
//  Created by Jaesung Lee on 8/13/26.
//

import SwiftUI

struct GalleryGrid: View {
    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    var posts: [Post] = []
    
    @Binding var selectedPost: Post?
    @Binding var isSelectingProfile: Bool
    @Binding var profileCandidatePost: Post?
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns) {
                ForEach(posts) { post in
                    Button {
                        let isSelected = selectedPost?.id == post.id
                        if isSelected {
                            profileCandidatePost = nil
                            selectedPost = nil
                        } else {
                            profileCandidatePost = post
                            selectedPost = post
                        }
                    } label: {
                        GalleryItemView(post: post)
                    }
//                    .selectionDisabled(!selectedPost)
//                        .overlay(alignment: .topTrailing) {
//                            if isSelectingProfile {
//                                let isSelected = isSelectingProfile
//                                    ? profileCandidatePost?.persistentModelID == post.persistentModelID
//                                    : selectedPostIDs.contains(post.id)
//                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
//                                    .foregroundStyle(isSelected ? .blue : .gray)
//                                    .padding(8)
//                            }
//                        }
                        .overlay {
                            if let selectedPost, selectedPost.id == post.id {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.colorGray, lineWidth: 2)
                            }
                        }
//                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
//                        .onTapGesture {
//                            if isSelectingProfile {
//                                withAnimation(.spring()) { profileCandidatePost = post }
//                            } else if selectedTab {
//                                if selectedPostIDs.contains(post.id) {
//                                    selectedPostIDs.remove(post.id)
//                                } else {
//                                    selectedPostIDs.insert(post.id)
//                                    withAnimation(.spring()) { showActionDialog = true }
//                                }
//                            } else {
//                                selectedPost = post
//                            }
//                        }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var selectedPost: Post? = nil
    @Previewable @State var isSelectingProfile: Bool = false
    @Previewable @State var profileCandidatePost: Post? = nil
    GalleryGrid(
        posts: [
            Post(lines: [.init(points: [.init(x: 5, y: 5), .init(x: 400, y: 100)])], text: "", isMine: false),
            Post(lines: [.init(points: [.init(x: 5, y: 5), .init(x: 400, y: 100)])], text: "", isMine: false),
        ],
        selectedPost: $selectedPost,
        isSelectingProfile: $isSelectingProfile,
        profileCandidatePost: $profileCandidatePost
    )
}
