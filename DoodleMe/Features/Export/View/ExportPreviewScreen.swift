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

    @State private var files: [URL] = []
    @State private var current = 0

    var body: some View {
        GeometryReader { proxy in
            TabView(selection: $current) {
                ForEach(pages) { page in
                    card(page, in: proxy)
                        .tag(page.id)
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
            // 버튼을 **카드 폭에 맞춰** 얹는다. 안전영역은 여기서만 지킨다.
            //
            // 바깥에 두면 화면 폭을 차지해, 카드가 9:16 이라 좌우가 남는
            // 아이패드 가로에서 버튼만 검은 여백 맨 끝에 붙는다.
            // 카드와 관계없는 것처럼 보이고 1180 폭에서는 손도 닿지 않는다.
            .overlay(alignment: .top) {
                topBar
                    .frame(maxWidth: ExportCardLayout.size.width * fit(in: proxy.size))
                    .padding(.top, proxy.safeAreaInsets.top)
            }
        }
        // `.ignoresSafeArea()` 는 `GeometryReader` **자신**에게 걸어야 한다.
        //
        // 안쪽에 걸면 그리는 자리만 넓어지고 `proxy.size` 는 그대로 안전영역 안쪽(402x781)을
        // 돌려준다. 그러면 배율이 0.897 로 떨어져 카드가 화면 한가운데 작게 뜬다.
        // `PaperBackground` 주석에 적힌 것과 같은 함정이다.
        .ignoresSafeArea()
        .task { bake() }
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
    private func card(_ page: ExportPage, in proxy: GeometryProxy) -> some View {
        GeometryReader { inner in
            ZStack {
                Self.backdrop

                // 둥근 모서리와 그림자는 **화면에서만** 붙는다.
                // 굽는 쪽(`bake`)은 카드를 따로 그리므로 내보내는 파일에는 들어가지 않는다.
                //
                // 카드가 9:16 이라 위아래에 배경이 남는데, 종이와 배경 색이 거의 같아
                // 종이가 화면 끝에서 **잘린 것처럼** 보였다.
                // 사진 앱이 사진 한 장을 보여줄 때와 같은 모양으로 두면 한 장이라는 게 바로 읽힌다.
                page.card
                    .clipShape(RoundedRectangle(cornerRadius: Self.previewCornerRadius,
                                                style: .continuous))
                    .scaleEffect(fit(in: proxy.size))
                    .shadow(color: .black.opacity(0.45), radius: 20, y: 8)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .offset(y: proxy.frame(in: .global).minY - inner.frame(in: .global).minY)
        }
    }

    /// 카드를 화면에 들어가게 맞추는 배율. 잘리지 않게 짧은 쪽에 맞춘다.
    ///
    /// 카드는 9:16 인데 아이폰 화면은 그보다 길쭉해(402x874 = 9:19.6) 폭에 맞춘다.
    /// 그러면 위아래에 각 80 쯤 빈자리가 남는다 — **이건 잘못이 아니라 그대로가 맞다.**
    /// 꽉 채우려고 키우면 화면에 보이는 것과 실제로 나가는 그림이 달라진다.
    /// 남는 자리는 닫기·공유 버튼이 앉아 종이를 가리지 않게 된다.
    private func fit(in size: CGSize) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return 1 }
        return min(size.width / ExportCardLayout.size.width,
                   size.height / ExportCardLayout.size.height)
    }

    private func bake() {
        files = pages.compactMap {
            ExportRenderer.temporaryFile($0.card, name: "\(fileName)-\($0.id + 1)")
        }
    }

    /// 카드 위에 떠 있는 버튼 두 개.
    private var topBar: some View {
        HStack {
            Button(action: onClose) { buttonFace("xmark") }
                .buttonStyle(.glass)
                .accessibilityLabel("닫기")

            Spacer()

            // 애플 HIG 「Activity views」 — 공유 버튼으로 시스템 시트를 연다.
            // 사진 저장·인스타그램·AirDrop 이 전부 이 안에 들어 있어 버튼을 따로 두지 않는다.
            //
            // 여러 장이면 전부 넘긴다. 사진 앱에 다 저장해 두면
            // 인스타그램에서 골라 캐러셀 한 게시물로 올릴 수 있다.
            if !files.isEmpty {
                ShareLink(items: files) { buttonFace("square.and.arrow.up") }
                    .buttonStyle(.glass)
                    .accessibilityLabel(files.count > 1 ? "\(files.count)장 공유" : "공유")
            }
        }
        .padding(.horizontal, Self.sideInset)
        // `.glass` 가 기본으로 주는 모양은 캡슐이라 44 짜리 글리프에 좌우 여백이 붙어
        // 알약처럼 늘어난다. 갤러리 상단 버튼들과 같은 원으로 맞춘다.
        .buttonBorderShape(.circle)
    }

    /// 버튼 알맹이. 바탕은 `.glass` 버튼 스타일이 깔아 준다.
    ///
    /// 흰 원을 직접 그리지 않는다.
    /// 애플 HIG 「Materials」 — *Liquid Glass forms a distinct functional layer for controls
    /// and navigation elements … that floats above the content layer* —
    /// 카드 위에 떠 있는 이 두 개가 바로 그 자리다.
    ///
    /// 갤러리 상단 버튼은 Figma 가 흰 원·먹색 원으로 정해 둔 것이라 그대로 두고,
    /// 여기만 유리로 간다. HIG 도 *Use Liquid Glass effects sparingly … Limit these effects
    /// to the most important functional elements* 라고 못박는다.
    ///
    /// 재질을 우리가 고르지 않는다. 시스템이 뒤에 무엇이 있는지 보고 정한다 —
    /// 어두운 바탕 위에서도, 종이 위로 걸쳐도 알아서 읽히게 맞춘다.
    private func buttonFace(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.title3.weight(.semibold))
            .frame(width: 44, height: 44)
    }

    private static var sideInset: CGFloat { 18 }

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
