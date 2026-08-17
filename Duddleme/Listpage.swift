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

    @State private var segmentedBar: Int = 0
    @State private var selectedTab: Bool = false
    @AppStorage("userName") private var inputName = ""


    @State private var selectedPostIDs: Set<PersistentIdentifier> = []
    @State private var showActionDialog = false
    @State private var selectedPost: Post? = nil
    @State private var isSelectingProfile = false
    @State private var profileCandidatePost: Post? = nil
    @State private var showProfileEditPopup = false
    @State private var confettiTrigger = 0

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
                                Image("profile.default")
                                    .resizable()
                                    .scaledToFill()
                                    .onTapGesture {
                                        withAnimation(.spring()) { isSelectingProfile = true }
                                    }
                            }
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 2, y: 2)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "pencil")
                                .foregroundStyle(.gray)
                                .padding(6)
                                .background(Circle().fill(.white.opacity(0.6)))
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 1, y: 1)
                                .offset(x: 5, y: 5)
                        }
                        .overlay { ConfettiBurst(trigger: confettiTrigger) }
                        .offset(y: 5)

                        ProfileNameView(profileName: $inputName)
                            .padding(.bottom, 15)



                        CustomSegmentedControl(
                            selection: $segmentedBar,
                            titles: ["너가 그린", "내가 그린"]
                        )
                        .padding(.bottom, 20)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing){
                                Button(selectedTab ? "취소" : "편집") {
                                    selectedTab.toggle()
                                    if !selectedTab {
                                        selectedPostIDs.removeAll()
                                    }
                                }
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
                            .opacity(0.9)
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
                            HStack(spacing: 24) {
                                Button {
                                    for post in allPosts {
                                        post.isProfile = selectedPostIDs.contains(post.persistentModelID)
                                    }
                                    confettiTrigger += 1
                                    selectedPostIDs.removeAll()
                                    selectedTab = false
                                    withAnimation(.spring()) { showActionDialog = false }
                                } label: {
                                    Text("프로필로 설정")
                                        .padding(.horizontal, 12)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .font(.body)
                                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 30))
                                        .foregroundStyle(.white)
                                }

                                Button(role: .destructive) {
                                    for post in allPosts where selectedPostIDs.contains(post.persistentModelID) {
                                        modelContext.delete(post)
                                    }
                                    selectedPostIDs.removeAll()
                                    selectedTab = false
                                    withAnimation(.spring()) { showActionDialog = false }
                                } label: {
                                    Text("삭제")
                                        .padding(.horizontal, 12)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
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
                        .padding(.top, 30)
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
                        .overlay {
                            Circle()
                                .strokeBorder(.accent.opacity(0.3), lineWidth: 1)
                        }
                        //                        .shadow(radius: 4)

                        Text("프로필로 설정하시겠습니까?")
                            .font(.headline)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 24) {
                            Button("예") {
                                for post in allPosts {
                                    post.isProfile = (post.persistentModelID == candidate.persistentModelID)
                                }
                                confettiTrigger += 1
                                withAnimation(.spring()) {
                                    profileCandidatePost = nil
                                    isSelectingProfile = false
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 30))
                            .foregroundStyle(.white)

                            Button("아니오", role: .destructive) {
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
                        
                        HStack(spacing: 24) {
                            Button("예") {
                                withAnimation(.spring()) {
                                    showProfileEditPopup = false
                                    isSelectingProfile = true
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 30))
                            .foregroundStyle(.white)
                            
                            Button("삭제", role: .destructive) {
                                for post in allPosts where post.isProfile {
                                    post.isProfile = false
                                }
                                withAnimation(.spring()) { showProfileEditPopup = false }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                .gray.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 30)
                            )
                        }
                    }
                    .padding(50)
                    .background(.white, in: RoundedRectangle(cornerRadius: 30))
                    .padding(.horizontal, 40)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .toolbarVisibility((selectedPost == nil && !showActionDialog) ? .visible : .hidden, for: .tabBar, .navigationBar)
            .ignoresSafeArea()
        }
    }
}



struct ProfileNameView: View {
    @Binding var profileName: String

    @State private var showingEditor = false
    @State private var draftName = ""

    var body: some View {
        Button {
            draftName = profileName
            showingEditor = true
        } label: {
            Text(profileName.isEmpty ? "이름" : profileName)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(profileName.isEmpty ? .gray : .primary)
                .padding(.top, 17)
        }
        .buttonStyle(.plain)
        .alert("프로필 이름", isPresented: $showingEditor) {
            TextField("이름", text: $draftName)
            Button("저장") {
                let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                profileName = trimmed.isEmpty ? profileName : trimmed
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("프로필에 표시되는 이름을 수정합니다.")
        }
    }
}

struct CustomSegmentedControl: View {
    @Binding var selection: Int
    let titles: [String]
    @Namespace private var segmentAnimation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<titles.count, id: \.self) { index in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selection = index
                    }
                } label: {
                    Text(titles[index])
                        .font(selection == index
                              ? .system(size: 16, weight: .semibold, design: .rounded)
                              : .system(size: 14, weight: .regular))
                        .foregroundColor(selection == index ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 35)
                        .background {
                            if selection == index {
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(.white)
                                    .shadow(color: .black.opacity(0.12), radius: 8)
                                    .matchedGeometryEffect(id: "segment", in: segmentAnimation)
                            }
                        }
                }
            }
        }
        .background(Color(red: 0.97, green: 0.98, blue: 0.98), in: RoundedRectangle(cornerRadius: 29))
        
    }
}

struct ConfettiBurst: View {
    let trigger: Int

    @State private var particles: [ConfettiParticle] = []
    @State private var progress: CGFloat = 0

    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(particle.color)
                    .frame(width: particle.width, height: particle.height)
                    .rotationEffect(.degrees(particle.spin * Double(progress)))
                    .offset(
                        x: CGFloat(cos(particle.angle)) * CGFloat((60 + particle.distance * progress)),
                        y: CGFloat(sin(particle.angle)) * CGFloat((60 + particle.distance * progress))
                    )
                    .opacity(Double(1 - progress))
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            particles = (0..<24).map { index in
                ConfettiParticle(
                    angle: Double(index) / 24 * 2 * .pi + .random(in: -0.2...0.2),
                    distance: .random(in: 50...110),
                    color: colors.randomElement() ?? .yellow,
                    width: .random(in: 4...7),
                    height: .random(in: 7...12),
                    spin: .random(in: -540...540)
                )
            }
            progress = 0
            withAnimation(.easeOut(duration: 0.9)) {
                progress = 1
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let angle: Double
    let distance: CGFloat
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let spin: Double
}

#Preview {
    Listpage()
        .modelContainer(for: Post.self, inMemory: true)
}
