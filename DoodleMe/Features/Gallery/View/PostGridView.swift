//
//  PostGridView.swift
//  DoodleMe
//
//  Created by Apple Developer Academy on 8/11/26.
//

import SwiftUI
import SwiftData

struct PostGridView: View {
    
    // 필터·정렬을 SwiftData 에 맡긴다. 메모리에서 filter 하지 않으므로 순서도 항상 최신순으로 보장된다.
    @Query(filter: #Predicate<Post> { $0.isMine },
           sort: \Post.createdAt, order: .reverse) private var postsByMe: [Post]
    @Query(filter: #Predicate<Post> { !$0.isMine },
           sort: \Post.createdAt, order: .reverse) private var postsByOthers: [Post]
    /// 프로필로 고를 수 있는 후보(이미 프로필인 그림은 제외).
    @Query(filter: #Predicate<Post> { !$0.isProfile },
           sort: \Post.createdAt, order: .reverse) private var profileCandidates: [Post]

    @Binding var selectedPostIDs: Set<PersistentIdentifier>
    @Binding var segmentedBar: Int
    @Binding var selectedTab: Bool
    @Binding var showActionDialog: Bool
    
    @Binding var selectedPost: Post?
    @Binding var isSelectingProfile: Bool
    @Binding var profileCandidatePost: Post?

    var body: some View {
        let currentPosts = isSelectingProfile
            ? profileCandidates
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
                            Image(.memoFront)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 170)
                                .clipped()
                                .overlay {
                                    DoodleImageView(drawingData: post.drawingData)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(alignment: .topTrailing) {
                                    if selectedTab || isSelectingProfile {
                                        let isSelected = isSelectingProfile
                                            ? profileCandidatePost?.persistentModelID == post.persistentModelID
                                            : selectedPostIDs.contains(post.persistentModelID)
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
                                        if selectedPostIDs.contains(post.persistentModelID) {
                                            selectedPostIDs.remove(post.persistentModelID)
                                        } else {
                                            selectedPostIDs.insert(post.persistentModelID)
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
