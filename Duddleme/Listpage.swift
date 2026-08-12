//
//  File.swift
//  Teritemps1
//
//  Created by Apple Developer Academy on 8/5/26.
//

import SwiftUI
import SwiftData

struct Listpage: View {

    @Query private var allPosts: [Post]

    var postsByMe: [Post] {
        allPosts.filter { $0.isMine}
    }
    var postsByOthers: [Post] {
        allPosts.filter { !$0.isMine }
    }

    @Environment(\.modelContext) private var modelContext

    @State private var segmentedBar: Bool = false
    @State private var selectedTab: Bool = false
    @AppStorage("userName") private var inputName = ""
    @FocusState private var isFocused: Bool


    @State private var selectedPostIDs: Set<PersistentIdentifier> = []
    @State private var showActionDialog = false
    @State private var selectedPost: Post? = nil
    @State private var isSelectingProfile = false
    @State private var profileCandidatePost: Post? = nil
    @State private var showProfileEditPopup = false

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack{
            ZStack {
                GeometryReader { proxy in
                    Image("papertype1")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width)
                        .clipped()
                        .ignoresSafeArea()
                }

                VStack {
                    VStack {
                        ZStack{
                            Circle()
                                .foregroundStyle(.white)

                            if let profilePost = allPosts.first(where: { $0.isProfile }) {
                                Canvas { context, size in
                                    let scale = size.width / 350
                                    context.transform = CGAffineTransform(scaleX: scale, y: scale)
                                    for line in profilePost.lines {
                                        var path = Path()
                                        path.addLines(line.points)
                                        context.stroke(path, with: .color(.black), lineWidth: 2)
                                    }
                                }
                                .onTapGesture {
                                    withAnimation(.spring()) { showProfileEditPopup = true }
                                }
                            } else {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.black)
                                    .opacity(0.15)
                                    .onTapGesture {
                                        withAnimation(.spring()) { isSelectingProfile = true }
                                    }
                            }
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 2, y: 2)
                        .offset(y: 5)


                        if inputName.isEmpty {
                            Image(systemName: "pencil")
                                .offset(x: 30,y: 22 )
                                .foregroundStyle(.gray)
                        }

                        TextField("이름", text: $inputName)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 20))
                            .fontWeight(.bold)
                            .padding(.bottom, 15)
                            .focused($isFocused)
                            .onChange(of: inputName) { oldValue, newValue in
                                if newValue.count > 10 {
                                    inputName = String(newValue.prefix(10))
                                }

                            }



                        Picker("창 선택", selection: $segmentedBar) {
                            Text("By others").tag(false)
                            Text("By me").tag(true)

                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 20)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 2)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing){
                                Button(selectedTab ? "Cancel" : "Select") {
                                    selectedTab.toggle()
                                    if !selectedTab {
                                        selectedPostIDs.removeAll()
                                    }
                                }
                                .frame(width: 75)
                            }
                            // ToolbarItem(placement: .topBarLeading) {
                            //     Button("테스트+") {
                            //         let testPost = Post(lines: [], text: "테스트 by others", isMine: false)
                            //         modelContext.insert(testPost)
                            //     }
                            //     .foregroundStyle(.orange)
                            // }
                            if isSelectingProfile {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button("취소") {
                                        withAnimation(.spring()) {
                                            isSelectingProfile = false
                                            profileCandidatePost = nil
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 140)

                    LazyVGridDuddle(
                        selectedPostIDs: $selectedPostIDs,
                        segmentedBar: $segmentedBar,
                        selectedTab: $selectedTab,
                        showActionDialog: $showActionDialog,
                        selectedPost: $selectedPost,
                        isSelectingProfile: $isSelectingProfile,
                        profileCandidatePost: $profileCandidatePost
                    )
                    .frame(maxHeight: .infinity)

                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.horizontal)

                // ScaleUpView goes here
                if let selectedPost {
                    ZStack {
                        Color.white
                            .opacity(0.6)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation {
                                    self.selectedPost = nil
                                }
                            }

                        ScaleUpView(post: selectedPost)
                    }
                }

                // 커스텀 바텀 액션 시트
                if showActionDialog {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring()) {
                                showActionDialog = false
                                selectedPostIDs.removeAll()
                                selectedTab = false
                            }
                        }

                    VStack {
                        Spacer()
                        VStack(spacing: 0) {
                            HStack(spacing: 50) {
                                Button {
                                    for post in allPosts {
                                        post.isProfile = selectedPostIDs.contains(post.persistentModelID)
                                    }
                                    selectedPostIDs.removeAll()
                                    selectedTab = false
                                    withAnimation(.spring()) { showActionDialog = false }
                                } label: {
                                    Text("Set profile")
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 20)
                                        .font(.body)
                                        .background(.ultraThinMaterial.opacity(0.9), in: RoundedRectangle(cornerRadius: 30))
                                }

                                Button(role: .destructive) {
                                    for post in allPosts where selectedPostIDs.contains(post.persistentModelID) {
                                        modelContext.delete(post)
                                    }
                                    selectedPostIDs.removeAll()
                                    selectedTab = false
                                    withAnimation(.spring()) { showActionDialog = false }
                                } label: {
                                    Text("Delete")
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 20)
                                        .font(.body)
                                        .foregroundStyle(.red)
                                        .background(.ultraThinMaterial.opacity(0.9), in: RoundedRectangle(cornerRadius: 30))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)

                            Button {
                                selectedPostIDs.removeAll()
                                selectedTab = false
                                withAnimation(.spring()) { showActionDialog = false }
                            } label: {
                                Text("취소")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.black)
                                    .background(.timeColor1.opacity(0.6), in: RoundedRectangle(cornerRadius: 30))
                                    .padding(.top, 10)
                                    .padding(10)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                        .background(.white, in: RoundedRectangle(cornerRadius: 30))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                        .padding(.top, 15)
                        .padding(30)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // 프로필 설정 확인 팝업
                if let candidate = profileCandidatePost {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring()) { profileCandidatePost = nil }
                        }

                    VStack(spacing: 20) {
                        Canvas { context, size in
                            let scale = size.width / 350
                            context.transform = CGAffineTransform(scaleX: scale, y: scale)
                            for line in candidate.lines {
                                var path = Path()
                                path.addLines(line.points)
                                context.stroke(path, with: .color(.black), lineWidth: 2)
                            }
                        }
                        .frame(width: 80, height: 80)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)

                        Text("프로필로 설정하시겠습니까?")
                            .font(.headline)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 60) {
                            Button("예") {
                                for post in allPosts {
                                    post.isProfile = (post.persistentModelID == candidate.persistentModelID)
                                }
                                withAnimation(.spring()) {
                                    profileCandidatePost = nil
                                    isSelectingProfile = false
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 30))
                            .foregroundStyle(.white)

                            Button("아니오") {
                                withAnimation(.spring()) { profileCandidatePost = nil }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 30))
                        }
                    }
                    .padding(24)
                    .background(.white, in: RoundedRectangle(cornerRadius: 30))
                    .padding(.horizontal, 40)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }

                // 프로필 편집 팝업 (기존 프로필 탭 시)
                if showProfileEditPopup {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring()) { showProfileEditPopup = false }
                        }

                    VStack(spacing: 20) {
                        Text("프로필사진을 변경하시겠습니까?")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 30)
                            .padding(.top, 15)
                            .font(.system(size: 25))

                        HStack(spacing: 35) {
                            Button("예") {
                                withAnimation(.spring()) {
                                    showProfileEditPopup = false
                                    isSelectingProfile = true
                                }
                            }
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .fontWeight(.semibold)
                            .background(Color.accentColor.opacity(0.6), in: RoundedRectangle(cornerRadius: 30))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 2)

                            Button("삭제") {
                                for post in allPosts where post.isProfile {
                                    post.isProfile = false
                                }
                                withAnimation(.spring()) { showProfileEditPopup = false }
                            }
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .fontWeight(.semibold)
                            .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 30))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 2)
                        }
                    }
                    .padding(50)
                    .background(.white, in: RoundedRectangle(cornerRadius: 30))
                    .padding(.horizontal, 40)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .toolbarVisibility((selectedPost == nil && !showActionDialog) ? .visible : .hidden, for: .tabBar, .navigationBar)
            .onTapGesture {
                isFocused = false
            }
            .ignoresSafeArea()
        }
    }
}



#Preview {
    Listpage()
        .modelContainer(for: Post.self, inMemory: true)
}
