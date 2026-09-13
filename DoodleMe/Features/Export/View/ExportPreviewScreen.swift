//
//  ExportPreviewScreen.swift
//  DoodleMe
//

import SwiftUI

/// 내보낼 카드 한 장.
///
/// 고른 그림이 한 장에 다 안 들어가면 여러 장이 된다.
/// 인스타그램 캐러셀이 한 게시물에 20장까지 받으므로, 나눈 페이지를 그대로 올릴 수 있다.
struct ExportPage: Identifiable {
    let id: Int
    let card: AnyView

    init(id: Int, @ViewBuilder card: () -> some View) {
        self.id = id
        self.card = AnyView(card())
    }
}

/// 내보낼 카드를 먼저 보여 주는 화면.
///
/// Figma `iPhone 17 - 26 / 27 / 28` 이 402x871 아이폰 화면 모양이고 상태바까지 얹혀 있다 —
/// 그림 파일 규격이 아니라 **앱 안에서 보는 화면**이라는 뜻이다.
///
/// 무엇을 내보내는지 보고 누르게 한다. 한 번 나가면 되돌릴 수 없는 일이라
/// 미리 보여 주는 편이 낫다.
struct ExportPreviewScreen: View {

    let pages: [ExportPage]
    /// 임시 파일 이름의 앞자리. 공유 시트에서 파일명으로도 보인다.
    let fileName: String
    let onClose: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var files: [URL] = []
    @State private var current = 0
    /// 어느 자리에 올릴 판인지. 스토리로 시작한다 — 원래 이 화면이 만들어진 규격이다.
    @State private var ratio: ExportRatio = .story
    /// 올릴 장을 고르는 중인지.
    @State private var isChoosing = false
    /// 고른 장들. `ExportPage.id`(= `files` 의 자리)를 담는다.
    @State private var chosen: Set<Int> = []

    /// 고른 판형의 카드 크기.
    private var layout: ExportCardLayout { ExportCardLayout(ratio: ratio) }

    var body: some View {
        GeometryReader { proxy in
            TabView(selection: $current) {
                ForEach(Array(slides(in: proxy.size).enumerated()), id: \.offset) { index, slide in
                    slideView(slide, in: proxy)
                        .tag(index)
                }
            }
            // 페이지 점은 시스템 것을 그대로 쓴다. 아무것도 지정하지 않는다.
            //
            // `.page` 의 기본은 `IndexDisplayMode.automatic` —
            // *Displays an index view when there are more than one page.*
            // 한 장이면 알아서 안 내고 여러 장이면 낸다. 우리가 장수를 세어 `.always` 를
            // 걸어 둘 이유가 없다. 그건 「한 장일 때도 늘 켠다」 는 뜻이다.
            //
            // 배경(알약)도 지정하지 않는다. 기본이 HIG 「Page controls」 의 **Automatic** —
            // *Displays the background only when people interact with the control.*
            // `always` 로 두면 알약이 꼬리말 「@doodle.me」 를 통째로 덮는다.
            //
            // 점 색도 칠하지 않는다. HIG: *Avoid coloring indicator images… let the system
            // automatically color the indicators.*
            .tabViewStyle(.page)
            // 카드들이 저마다 폭을 알아야 한다. 한 군데서 내리면 안쪽이 전부 따라온다.
            .environment(\.exportRatio, ratio)
            // 버튼을 **카드 폭에 맞춰** 얹는다. 안전영역은 여기서만 지킨다.
            //
            // 바깥에 두면 화면 폭을 차지해, 카드가 9:16 이라 좌우가 남는
            // 아이패드 가로에서 버튼만 검은 여백 맨 끝에 붙는다.
            // 카드와 관계없는 것처럼 보이고 1180 폭에서는 손도 닿지 않는다.
            .overlay(alignment: .top) {
                topBar(in: proxy.size)
                    .frame(maxWidth: slideWidth(columns: cardsOnCurrentSlide(in: proxy.size))
                           * fit(in: proxy.size))
                    .padding(.top, topInset(in: proxy))
            }
        }
        // `.ignoresSafeArea()` 는 `GeometryReader` **자신**에게 걸어야 한다.
        //
        // 안쪽에 걸면 그리는 자리만 넓어지고 `proxy.size` 는 그대로 안전영역 안쪽(402x781)을
        // 돌려준다. 그러면 배율이 0.897 로 떨어져 카드가 화면 한가운데 작게 뜬다.
        // `PaperBackground` 주석에 적힌 것과 같은 함정이다.
        .ignoresSafeArea()
        // 판을 바꾸면 다시 굽는다. 공유 시트에는 지금 보고 있는 판만 나가야 한다.
        .task(id: ratio) { bake() }
    }

    /// 카드 한 장을 화면에 꽉 채워 놓는다.
    ///
    /// **`TabView` 가 내용을 제자리에 놓아 주지 않는다.**
    /// `GeometryReader` 는 화면 맨 위(y=0)에 서 있는데 그 안의 페이지는 y=14 에서 시작한다.
    /// 점을 내든 안 내든(`indexDisplayMode`) 똑같이 14 만큼 밀린다 — 재서 확인했다.
    /// 그대로 두면 종이 위쪽에 흰 띠가 14 남고 아래는 그만큼 잘린다.
    ///
    /// 그래서 페이지가 놓인 자리를 직접 재서 되돌린다.
    /// `14` 를 적어 두지 않는 것은 기기마다 다를 수 있어서다 — 두 자리의 차이를 그때그때 잰다.
    /// 한 장(좁은 화면) 또는 두 장(눕힌 아이패드)을 담은 슬라이드 하나.
    ///
    /// **`TabView` 가 내용을 제자리에 놓아 주지 않는다.**
    /// `GeometryReader` 는 화면 맨 위(y=0)에 서 있는데 그 안의 페이지는 y=14 에서 시작한다.
    /// 점을 내든 안 내든(`indexDisplayMode`) 똑같이 14 만큼 밀린다 — 재서 확인했다.
    /// 그대로 두면 종이 위쪽에 흰 띠가 14 남고 아래는 그만큼 잘린다.
    ///
    /// 그래서 페이지가 놓인 자리를 직접 재서 되돌린다.
    /// `14` 를 적어 두지 않는 것은 기기마다 다를 수 있어서다 — 두 자리의 차이를 그때그때 잰다.
    private func slideView(_ slide: [ExportPage], in proxy: GeometryProxy) -> some View {
        GeometryReader { inner in
            ZStack {
                Self.backdrop

                // 둥근 모서리와 그림자는 **화면에서만** 붙는다.
                // 굽는 쪽(`bake`)은 카드를 따로 그리므로 내보내는 파일에는 들어가지 않는다.
                //
                // 카드가 9:16 이라 위아래(또는 좌우)에 배경이 남는데, 종이와 배경 색이 거의 같아
                // 종이가 화면 끝에서 **잘린 것처럼** 보였다.
                // 사진 앱이 사진 한 장을 보여줄 때와 같은 모양으로 두면 한 장이라는 게 바로 읽힌다.
                HStack(spacing: Self.slideGap) {
                    ForEach(slide) { page in
                        page.card
                            .clipShape(RoundedRectangle(cornerRadius: Self.previewCornerRadius,
                                                        style: .continuous))
                            .shadow(color: .black.opacity(0.45), radius: 20, y: 8)
                            // 고르지 않은 장을 흐리게 덮지 않는다.
                            //
                            // 한때 `opacity` 로 눌러 두었는데 세 가지가 한꺼번에 어긋났다 —
                            // 종이와 말풍선이 **따로따로** 반투명해져 흰 말풍선이 회색 위에 뜬 것처럼
                            // 겹쳐 보였고, 카드가 어두워지면서 그 위에 떠 있는 유리 버튼이
                            // 어두운 배경에 녹아 닫기·공유 글리프가 사라졌다.
                            //
                            // 사진 앱도 고르지 않은 것을 흐리게 하지 않는다. 켜진 것에만 표를 단다.
                            // 동그라미는 카드 **오른쪽 아래**에 단다.
                            //
                            // 사진 앱이 여러 장을 고를 때 두는 자리가 거기다 — 썸네일 오른쪽 아래.
                            // 시뮬레이터에서 열어 확인했다.
                            // 여기서는 이유가 하나 더 있다. 9:16 카드가 화면을 꽉 채우는 곳에서는
                            // 버튼 줄이 카드 윗변 **안쪽**으로 들어오기 때문에, 위에 달면
                            // 공유 버튼과 겹쳐 둘 다 못 읽는다 — 겹쳐 봤다.
                            // 카드 오른쪽 아래는 꼬리말(가운데)에서 비켜나 있어 늘 비어 있다.
                            .overlay(alignment: .bottomTrailing) {
                                if isChoosing {
                                    selectionBadge(isOn: chosen.contains(page.id))
                                        // 카드와 함께 줄어드는 것을 되돌린다. 자세한 까닭은 아래.
                                        .scaleEffect(1 / fit(in: proxy.size), anchor: .bottomTrailing)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { if isChoosing { toggle(page.id) } }
                            .accessibilityAddTraits(chosen.contains(page.id) ? [.isSelected] : [])
                    }
                }
                .scaleEffect(fit(in: proxy.size))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .offset(y: proxy.frame(in: .global).minY - inner.frame(in: .global).minY)
        }
    }

    /// 한 번에 보여 줄 장수.
    ///
    /// 눕힌 아이패드는 좌우가 크게 남는다 — 9:16 카드 하나를 가운데 놓으면
    /// 양옆 검은 띠가 화면의 40% 를 먹는다. 두 장을 나란히 놓으면 그 자리가 살고
    /// 넘길 횟수도 반으로 준다.
    ///
    /// 세로는 좌우가 남지 않고, 아이폰은 어느 방향이든 좁다.
    private func columns(in size: CGSize) -> Int {
        DoodleLayout.isWide(size.width, sizeClass: horizontalSizeClass)
            && size.width > size.height ? 2 : 1
    }

    /// 넘길 단위. 한 슬라이드에 `columns` 장이 들어간다.
    private func slides(in size: CGSize) -> [[ExportPage]] {
        pages.chunked(by: columns(in: size))
    }

    /// 지금 보고 있는 슬라이드에 **실제로** 놓인 장수.
    ///
    /// 마지막 슬라이드는 `columns` 보다 적을 수 있다 — 5쪽을 두 장씩 넘기면 마지막은 한 장이다.
    /// 버튼 줄을 늘 `columns` 기준으로 재면, 그 한 장짜리 슬라이드에서 닫기·공유가
    /// 카드에서 멀찍이 떨어진 검은 여백 끝에 붙는다. 눕힌 아이패드에서 실제로 그랬다.
    private func cardsOnCurrentSlide(in size: CGSize) -> Int {
        let all = slides(in: size)
        guard all.indices.contains(current) else { return columns(in: size) }
        return all[current].count
    }

    /// 슬라이드 하나가 원래 좌표계에서 차지하는 폭.
    private func slideWidth(columns: Int) -> CGFloat {
        layout.size.width * CGFloat(columns) + Self.slideGap * CGFloat(columns - 1)
    }

    /// 나란히 놓인 카드 사이.
    private static let slideGap: CGFloat = 24

    /// 버튼 줄이 화면 위에서 떨어져 있는 정도.
    ///
    /// **카드 위에 자리가 있으면 카드 밖에 선다.**
    /// 판이 넓어질수록 카드는 낮아져 위아래 빈 바탕이 넓어진다 —
    /// 1:1 은 아이폰에서 위로 236 이 남는다. 그 자리를 두고 카드 안으로 들어가면
    /// 세그먼트가 제목(「○○가 그린」)을 덮는다. 실제로 덮였다.
    ///
    /// 자리가 모자라면 예전대로 카드 윗변 안쪽으로 들어간다.
    /// 9:16 을 아이폰에 띄우면 카드가 화면을 거의 채워 위에 20 밖에 안 남는데,
    /// 거기서는 제목 위 여백(106)이 넉넉해 겹치지 않는다.
    ///
    /// 어느 쪽이든 안전영역 아래로 `topGap` 만큼은 내려온다.
    /// 가로에서는 안전영역이 24 밖에 안 돼 그대로 두면 버튼이 화면 맨 위에 붙는다.
    private func topInset(in proxy: GeometryProxy) -> CGFloat {
        let cardTop = (proxy.size.height - layout.size.height * fit(in: proxy.size)) / 2
        let safeTop = proxy.safeAreaInsets.top

        let aboveCard = cardTop - Self.topGap - Self.barHeight
        if aboveCard >= safeTop + Self.topGap { return aboveCard }

        return max(safeTop, cardTop) + Self.topGap
    }

    /// 카드를 화면에 들어가게 맞추는 배율. 잘리지 않게 짧은 쪽에 맞춘다.
    ///
    /// 카드는 9:16 인데 아이폰 화면은 그보다 길쭉해(402x874 = 9:19.6) 폭에 맞춘다.
    /// 그러면 위아래에 각 80 쯤 빈자리가 남는다 — **이건 잘못이 아니라 그대로가 맞다.**
    /// 꽉 채우려고 키우면 화면에 보이는 것과 실제로 나가는 그림이 달라진다.
    /// 남는 자리는 닫기·공유 버튼이 앉아 종이를 가리지 않게 된다.
    private func fit(in size: CGSize) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return 1 }

        // 여러 장이면 아래쪽에 페이지 점이 설 자리를 비운다.
        //
        // 비우지 않으면 카드가 화면 높이를 꽉 채우는 곳에서 점이 **종이 위에** 얹힌다 —
        // 아이패드 세로의 9:16 이 정확히 그랬고, 점이 「@doodle.me」 바로 아래에 찍혀
        // 내보낸 그림에 들어가는 것처럼 보였다.
        // 위아래를 같이 비워야 카드가 계속 한가운데에 선다.
        let room = pages.count > 1 ? Self.indexRoom * 2 : 0
        return min(size.width / slideWidth(columns: columns(in: size)),
                   max(size.height - room, 1) / layout.size.height)
    }

    private func bake() {
        // 판형을 파일 이름에 남긴다. 사진 앱에 여러 판을 저장해 두었을 때
        // 어느 것이 스토리용이고 어느 것이 게시물용인지 열어 보지 않고 가린다.
        files = pages.compactMap {
            ExportRenderer.temporaryFile($0.card,
                                         ratio: ratio,
                                         name: "\(fileName)-\(ratio.fileTag)-\($0.id + 1)")
        }
    }

    /// 카드 위에 떠 있는 줄. 양 끝에 버튼, 가운데에 판형 세그먼트.
    ///
    /// 고르는 중에는 같은 자리가 「취소 · 몇 장 골랐는지 · 공유」 로 바뀐다.
    /// 갤러리의 고르기 막대와 같은 짜임이다 — 나가는 길이 왼쪽, 하는 일이 오른쪽.
    private func topBar(in size: CGSize) -> some View {
        HStack {
            Button(action: isChoosing ? stopChoosing : onClose) { buttonFace("xmark") }
                .accessibilityLabel(isChoosing ? "고르기 취소" : "닫기")

            Spacer()

            shareButton(in: size)
        }
        .padding(.horizontal, Self.sideInset)
        // 세그먼트를 **겹쳐서** 가운데에 둔다.
        //
        // 같은 `HStack` 에 넣으면 공유 버튼이 아직 안 나왔을 때(굽는 중) 한쪽으로 쏠린다.
        // 겹쳐 두면 버튼이 있든 없든 늘 화면 한가운데 선다.
        .overlay { isChoosing ? AnyView(chosenCount) : AnyView(ratioPicker) }
    }

    /// 공유로 가는 버튼.
    ///
    /// **장이 둘 이상이면 곧장 시트를 열지 않고 무엇을 올릴지 먼저 묻는다.**
    /// 그림 열 장을 골라 내보내면 카드가 넉 장까지 나오는데, 인스타그램에 올리고 싶은 것은
    /// 그중 한둘일 때가 많다. 전부 넘겨 놓고 시트에서 빼게 하면 이미 늦다 —
    /// 시스템 시트는 넘긴 것을 골라내는 자리가 아니다.
    ///
    /// 한 장뿐이면 물을 것이 없으니 그대로 시트를 연다.
    @ViewBuilder
    private func shareButton(in size: CGSize) -> some View {
        if isChoosing {
            ShareLink(items: chosenFiles) { buttonFace("square.and.arrow.up") }
                .disabled(chosen.isEmpty)
                .accessibilityLabel("고른 \(chosen.count)장 공유")
        } else if files.count > 1 {
            Menu {
                let here = filesOnCurrentSlide(in: size)
                // 보고 있는 것이 곧 전부이면 이 줄을 내지 않는다 —
                // 눕힌 아이패드에서 두 장을 나란히 보고 있으면 「보고 있는 2장」과
                // 「전체 2장」이 같은 말이 되어 같은 것을 두 번 묻는 꼴이 된다.
                if here.count < files.count {
                    ShareLink(items: here) {
                        Label(here.count > 1 ? "보고 있는 \(here.count)장" : "이 장만",
                              systemImage: "rectangle.portrait")
                    }
                }
                ShareLink(items: files) {
                    Label("전체 \(files.count)장", systemImage: "rectangle.stack")
                }
                Button {
                    startChoosing()
                } label: {
                    Label("골라서…", systemImage: "checkmark.circle")
                }
            } label: {
                buttonFace("square.and.arrow.up")
            }
            .accessibilityLabel("공유")
        } else if !files.isEmpty {
            // 애플 HIG 「Activity views」 — 공유 버튼으로 시스템 시트를 연다.
            // 사진 저장·인스타그램·AirDrop 이 전부 이 안에 들어 있어 버튼을 따로 두지 않는다.
            ShareLink(items: files) { buttonFace("square.and.arrow.up") }
                .accessibilityLabel("공유")
        }
    }

    /// 고르는 중에 세그먼트 자리에 서는 글. 판형은 이때 바꿀 수 없다 —
    /// 판을 바꾸면 카드를 다시 구워야 해서 고른 것이 가리키던 파일이 사라진다.
    private var chosenCount: some View {
        // 양옆 버튼과 같은 흰 바탕이다. 유리로 두었더니 검은 배경 위에서 알약 윤곽이
        // 사라져 글자만 허공에 뜬 것처럼 보였다 — 한 줄에 선 셋은 같은 재질이어야 한 줄로 읽힌다.
        Text(chosen.isEmpty ? "올릴 장을 고르세요" : "\(chosen.count)장 고름")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.doodlePrimary)
            .padding(.horizontal, 16)
            .frame(height: Self.barHeight)
            .background(.white.opacity(0.95), in: Capsule())
            .shadow(color: .black.opacity(0.2), radius: 7.5, y: 4)
    }

    private func startChoosing() {
        // 하나도 고르지 않은 채로 연다. 「골라서」 를 누른 사람은 고를 뜻이 있는 것이라
        // 전부 켜 두면 **켜는 것이 아니라 끄는 일**부터 시켜야 한다.
        chosen = []
        isChoosing = true
    }

    private func stopChoosing() {
        isChoosing = false
        chosen = []
    }

    /// 고른 순서가 아니라 **카드 차례대로** 넘긴다.
    /// 인스타그램 캐러셀은 넘긴 차례로 실리므로, 그림 다음에 한마디가 오는 순서가 지켜져야 한다.
    private var chosenFiles: [URL] {
        files.enumerated().filter { chosen.contains($0.offset) }.map(\.element)
    }

    /// 지금 보고 있는 슬라이드에 놓인 장들. 눕힌 아이패드에서는 둘이다.
    private func filesOnCurrentSlide(in size: CGSize) -> [URL] {
        let all = slides(in: size)
        guard all.indices.contains(current) else { return files }
        return all[current].compactMap { files.indices.contains($0.id) ? files[$0.id] : nil }
    }

    private func toggle(_ id: Int) {
        if chosen.contains(id) { chosen.remove(id) } else { chosen.insert(id) }
    }

    /// 고르는 중에 카드마다 붙는 동그라미. 갤러리(`PostGridView`)와 같은 모양이다.
    ///
    /// **닫기·공유 버튼과 같은 44 로 선다.** 부르는 쪽에서 카드 배율을 되돌려 주기 때문이다.
    ///
    /// 이 동그라미는 카드 안(폭 490 좌표계)에 얹히므로 그냥 두면 카드와 함께 줄어든다.
    /// 그러면 판을 바꿀 때마다 크기가 달라진다 — 9:16 에서 42 로 버튼과 나란하던 것이
    /// 1:1 에서는 23 으로 절반이 된다. 재서 확인했다.
    /// 같은 화면에 선 세 개가 저마다 다른 크기로 보일 까닭이 없다.
    private func selectionBadge(isOn: Bool) -> some View {
        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
            // SF Symbol 의 원은 글꼴 크기의 0.9 쯤이라 48 이 버튼 지름 44 와 맞는다.
            .font(.system(size: 48, weight: isOn ? .semibold : .light))
            // 꺼진 동그라미는 **먹색**이다. 갤러리는 흰색을 쓰지만 거기는 고르는 동안
            // 카드가 회색으로 눌려 있어 흰 테두리가 떠오른다. 여기는 흰 종이 그대로라
            // 흰 동그라미가 종이에 묻힌다 — 구워 놓고 보니 있는지 없는지 알기 어려웠다.
            .foregroundStyle(isOn ? Color.white : Color.doodlePrimary.opacity(0.45),
                             isOn ? Color.doodlePrimary : Color.clear)
            .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
            // 배율을 되돌린 뒤라 이 여백도 화면 그대로다. 버튼이 화면 가에서 떨어진 만큼(18) 쯤.
            .padding(18)
    }

    /// 어느 자리에 올릴지 고르는 세그먼트.
    ///
    /// 애플 기본 `.segmented` 그대로다. HIG 「Segmented controls」 —
    /// *Use a segmented control to offer closely related choices that affect an object,
    /// state, or view* — 같은 그림을 어느 판으로 내보낼지가 꼭 그 자리다.
    ///
    /// 고르면 미리보기가 바로 그 판으로 바뀐다. 나가기 전에 무엇이 나갈지 보게 하는 것이
    /// 이 화면의 일이라, 굽는 순간에 묻는 메뉴보다 여기가 맞다.
    private var ratioPicker: some View {
        Picker("판형", selection: $ratio) {
            ForEach(ExportRatio.allCases) { ratio in
                Text(ratio.label)
                    .accessibilityLabel(ratio.accessibilityLabel)
                    .tag(ratio)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        // 좌우 버튼(각 44)과 부딪히지 않는 폭이다. 가장 좁은 아이폰에서도 60 씩 남는다.
        .frame(maxWidth: Self.ratioPickerWidth)
    }

    /// 버튼 알맹이. 갤러리 상단 버튼과 **같은 흰 원**이다.
    ///
    /// 처음에는 유리(`glassEffect`)로 갔다. HIG 「Materials」 가
    /// *Liquid Glass forms a distinct functional layer for controls and navigation elements …
    /// that floats above the content layer* 라고 하니 카드 위에 떠 있는 이 둘이 그 자리로 보였다.
    ///
    /// **어두운 바탕에서 사라졌다.** 이 화면은 앱에서 유일하게 배경이 검은 곳이고,
    /// 1:1·4:5 처럼 카드가 낮은 판에서는 버튼이 그 검은 자리 위에 선다.
    /// 유리는 뒤를 보고 스스로 어두워지는데, 그러면 어두운 바탕에 어두운 원이 되어
    /// 테두리도 글리프도 읽히지 않았다 — 화면을 찍어 확대해 보고서야 드러났다.
    ///
    /// 흰 원은 검은 바탕에서도 흰 종이 위에서도 또렷하다.
    /// 갤러리에서 누르던 것과 같은 모양이라 여기서 따로 배울 것도 없다.
    private func buttonFace(_ symbol: String) -> some View {
        Image(systemName: symbol)
            // 갤러리 상단 버튼(`GalleryPage`)과 같은 글리프 크기·굵기·색이다.
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(Color.doodlePrimary)
            .frame(width: DoodleMetrics.buttonSide, height: DoodleMetrics.buttonSide)
            // 갤러리는 흰색 80% 다. 여기서는 뒤가 검어 그만큼 비치면 회색으로 내려앉는다.
            .background(.white.opacity(0.95), in: Circle())
            .shadow(color: .black.opacity(0.2), radius: 7.5, y: 4)
    }

    private static var sideInset: CGFloat { 18 }
    /// 판형 세그먼트의 최대 폭.
    private static let ratioPickerWidth: CGFloat = 220
    /// 버튼 줄의 높이. 글리프 하나가 44 니 줄도 44 다.
    private static let barHeight: CGFloat = 44
    /// 카드 아래에 비워 두는 페이지 점 자리.
    private static let indexRoom: CGFloat = 44
    /// 버튼이 안전영역·카드 윗변에서 떨어지는 정도. 좌우 여백과 같은 값이다.
    private static let topGap: CGFloat = 18

    /// 카드 뒤에 까는 바탕.
    ///
    /// **앱에서 유일하게 어두운 화면이다.** 그럴 이유가 있다.
    /// 카드는 9:16 이라 19.5:9 인 화면에서 위아래가 남는데, 종이(241,241,246)와
    /// 원래 배경(242,242,247)이 **1 차이**라 경계가 보이지 않았다.
    /// 종이가 화면 끝에서 잘린 것처럼 읽혀 「내보내면 잘리나?」 하는 오해를 낳았다.
    /// 둥근 모서리와 그림자만으로는 모자랐다 — 흰 것 뒤에는 어두운 것이 있어야 한다.
    ///
    /// 셋로그가 만든 영상을 검은 판 위에 얹어 보여 주는 것과 같은 까닭이다.
    /// 이 화면은 감상하는 자리가 아니라 **무엇이 나가는지 확인하는 자리**다.
    private static let backdrop = Color(white: 0.13)

    /// 미리보기에서만 깎는 모서리. 카드 좌표(490 폭) 기준이라 화면에서는 20 쯤으로 보인다.
    private static let previewCornerRadius: CGFloat = 24
}
