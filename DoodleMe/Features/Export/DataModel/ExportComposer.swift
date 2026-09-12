//
//  ExportComposer.swift
//  DoodleMe
//

import SwiftUI

/// 고른 그림을 내보낼 카드 묶음으로 짠다.
///
/// **한 장이면 26번, 두 장부터 27번·28번이다.**
/// 한 장을 격자에 덩그러니 놓으면 다섯 칸이 비고, 제목도 「사람들이 그린」 이라
/// 한 사람이 그린 것에는 말이 맞지 않는다.
///
/// 여러 장이면 그림 격자를 앞에, 한마디 말풍선을 뒤에 놓는다.
/// 넘치면 버리지 않고 페이지를 늘린다 —
/// 인스타그램 캐러셀이 한 게시물에 20장까지 받으므로 그대로 올릴 수 있고,
/// 한 장에 우겨넣어 그림이 알아볼 수 없게 작아지는 것보다 낫다.
///
/// 갤러리 화면에서 떼어 둔 이유는 **화면 없이도 같은 카드를 만들 수 있어야** 해서다.
/// 1장부터 10장까지 모든 경우를 굽어 확인할 때 이 자리를 그대로 부른다 —
/// 화면을 거쳐 만든 카드와 다른 것을 검사하면 검사가 아니다.
enum ExportComposer {

    /// - Parameters:
    ///   - posts: 고른 그림. 최근 것이 앞에 오도록 이미 정렬돼 있어야 한다.
    ///   - myName: 앱을 쓰는 나.
    ///   - mine: 「내가 그린」 묶음인지. 제목의 두 이름이 자리를 바꾼다.
    static func pages(for posts: [Post], myName: String, mine: Bool) -> [ExportPage] {
        guard posts.count > 1 else {
            guard let only = posts.first else { return [] }
            return [ExportPage(id: 0) { ExportSinglePostCard(post: only, myName: myName) }]
        }

        var pages: [ExportPage] = []
        let (slices, gridBasis) = balancedSlices(posts, perPage: ExportDrawingsCard.perPage)
        for slice in slices {
            pages.append(ExportPage(id: pages.count) {
                ExportDrawingsCard(posts: slice, myName: myName, mine: mine, gridBasis: gridBasis)
            })
        }
        // 그림 뒤에 한마디를 붙인다. 한마디가 하나도 없으면 `paginate` 가 빈 배열을 주므로
        // 말풍선 장 자체가 생기지 않는다.
        for slice in ExportQuotesCard.paginate(posts) {
            pages.append(ExportPage(id: pages.count) {
                ExportQuotesCard(posts: slice, myName: myName, mine: mine)
            })
        }
        return pages
    }

    /// 그림을 쪽마다 **고르게** 나눈다. 돌려주는 둘째 값은 한 쪽의 최대 장수다.
    ///
    /// 앞에서부터 여섯 장씩 끊으면 마지막 쪽에 찌꺼기가 남는다 —
    /// 일곱 장을 고르면 1쪽 여섯 장, 2쪽 **한 장**이 되어 그 한 장이 종이 한가운데
    /// 덩그러니 놓인다. 구워 놓고 보니 스무 장 중 가장 허전한 카드였다.
    /// 쪽수는 그대로 두고 나누기만 고르게 하면 4·3 이 되어 둘 다 채워진다.
    ///
    /// 여섯의 배수는 그대로다 — 여섯 장이면 한 쪽, 열두 장이면 6·6 으로
    /// Figma 가 그린 2열 x 3행 배치를 지킨다.
    private static func balancedSlices(_ posts: [Post],
                                       perPage: Int) -> (slices: [[Post]], basis: Int) {
        let pageCount = max(1, (posts.count + perPage - 1) / perPage)
        let per = (posts.count + pageCount - 1) / pageCount
        return (posts.chunked(by: per), per)
    }
}
