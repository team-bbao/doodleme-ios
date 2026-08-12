//
//  LazyVGrid.swift
//  Duddleme
//
//  Created by Apple Developer Academy on 8/11/26.
//

import SwiftUI
import SwiftData

struct LazyVGridDuddle: View {
    
    @Query private var allPosts: [Post]
    
    @Binding var selectedPostIDs: Set<PersistentIdentifier>
    @Binding var segmentedBar: Bool
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
            : (segmentedBar ? postsByMe : postsByOthers)

        let gradientColors: [Color] = [
            .gradientTop,
            .gradientTop,
            .gradientBottom
        ]
        
        let columns = [
            GridItem(.flexible(), spacing: 30),
            GridItem(.flexible(), spacing: 30)
        ]

        if currentPosts.isEmpty {
            Text("0개의 항목")
                .foregroundStyle(.colorGray)
                .padding(.top, 70)
                .fontWeight(.bold)
                .font(.system(size: 25))
                .opacity(0.7)
            Spacer()
            
        } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(currentPosts) { post in
                            RoundedRectangle(cornerRadius: 12)
                                //     .fill(Color.white)
                                .fill(
                                        LinearGradient(
                                            colors: gradientColors,
                                            startPoint: .topTrailing,
                                            endPoint: .bottomLeading
                                        )
                                    )
                                .frame(height: 170)
                                .overlay {
                                    GeometryReader { geo in
                                        Canvas { context, size in
                                            let scaleX = geo.size.width / 350
                                            let scaleY = geo.size.height / 350
                                            context.transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
                                            for line in post.lines {
                                                var path = Path()
                                                path.addLines(line.points)
                                                context.stroke(path, with: .color(.black), lineWidth: 2)
                                            }
                                        }
                                    }
                                }
                                .overlay(alignment: .topTrailing) {
                                    if selectedTab || isSelectingProfile {
                                        let isSelected = isSelectingProfile
                                            ? profileCandidatePost?.persistentModelID == post.persistentModelID
                                            : selectedPostIDs.contains(post.id)
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(isSelected ? .blue : .gray)
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
    LazyVGridDuddle(
        selectedPostIDs: .constant([]),
        segmentedBar: .constant(false),
        selectedTab: .constant(false),
        showActionDialog: .constant(false),
        selectedPost: .constant(nil),
        isSelectingProfile: .constant(false),
        profileCandidatePost: .constant(nil)
    )
    .modelContainer(for: Post.self, inMemory: true)
}
