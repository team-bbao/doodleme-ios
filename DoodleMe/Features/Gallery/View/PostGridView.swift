//
//  PostGridView.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/11/26.
//

import SwiftUI
import SwiftData

struct PostGridView: View {
    
    @Query private var allPosts: [Post]
    
    @Binding var selectedPostIDs: Set<PersistentIdentifier>
    @Binding var segmentedBar: Int
    @Binding var selectedTab: Bool
    @Binding var showActionDialog: Bool
    var postsByMe: [Post] {
        allPosts.filter { $0.isMine}
    }
    var postsByOthers: [Post] {
        allPosts.filter { !$0.isMine }
    }
    
    @Binding var selectedPost: Post?
    @Binding var isSelectingProfile: Bool
    @Binding var profileCandidatePost: Post?

    var body: some View {
        let currentPosts = isSelectingProfile
            ? allPosts.filter { !$0.isProfile }
            : (segmentedBar == 1 ? postsByMe : postsByOthers)

        let columns = [
            GridItem(.flexible(), spacing: 30),
            GridItem(.flexible(), spacing: 30)
        ]

        if currentPosts.isEmpty {
            Text("친구의 얼굴을 그려보세요")
                .foregroundStyle(.colorGray)
                .padding(.top, 70)
                .fontWeight(.bold)
                .font(.system(size: 25))
                .opacity(0.4)
            Spacer()
            
        } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(currentPosts) { post in
                            Image("메모지.body")
                                .resizable()
                                .scaledToFill()
                                .frame(height: 170)
                                .clipped()
                                .overlay {
                                    GeometryReader { geo in
                                        Canvas { context, size in
                                            let scaleX = geo.size.width / 350
                                            let scaleY = geo.size.height / 390
                                            context.transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
                                            for line in post.lines {
                                                var path = Path()
                                                path.addLines(line.points)
                                                context.stroke(path, with: .color(.black), lineWidth: 2)
                                            }
                                        }
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(alignment: .topTrailing) {
                                    if selectedTab || isSelectingProfile {
                                        let isSelected = isSelectingProfile
                                            ? profileCandidatePost?.persistentModelID == post.persistentModelID
                                            : selectedPostIDs.contains(post.id)
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(isSelected ? Color.accent : .gray)
                                            .padding(8)
                                    }
                                }
                                .overlay {
                                    if isSelectingProfile {
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.colorGray, lineWidth: 2)
                                    }
                                }
                                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                                .onTapGesture {
                                    if isSelectingProfile {
                                        withAnimation(.spring()) { profileCandidatePost = post }
                                    } else if selectedTab {
                                        if selectedPostIDs.contains(post.id) {
                                            selectedPostIDs.remove(post.id)
                                        } else {
                                            selectedPostIDs.insert(post.id)
                                            withAnimation(.spring()) { showActionDialog = true }
                                        }
                                    } else {
                                        selectedPost = post
                                    }
                                }
                        }
                    }
                }
        }
    }
}

#Preview {
    PostGridView(
        selectedPostIDs: .constant([]),
        segmentedBar: .constant(0),
        selectedTab: .constant(false),
        showActionDialog: .constant(false),
        selectedPost: .constant(nil),
        isSelectingProfile: .constant(false),
        profileCandidatePost: .constant(nil)
    )
    .modelContainer(LocalDataStore.makePreviewContainer())
}
