//
//  ExportDrawingsCard.swift
//  DoodleMe
//

import PencilKit
import SwiftUI

/// 받은 그림 여러 장을 한 장에 모아 내보내는 카드. Figma `iPhone 17 - 27`(`222:1770`).
///
/// 「사람들이 그린 / ○○의 첫인상」 — 남들이 나를 그려 준 것들이라
/// 갤러리의 **「나를 그린」**(`isMine == false`) 묶음에서 고른 것을 받는다.
struct ExportDrawingsCard: View {

    /// 이 페이지에 실을 그림들. `perPage` 장을 넘겨 주지 않는다.
    let posts: [Post]
    /// 앱을 쓰는 나.
    let myName: String
    /// 내가 그린 것인지. 제목의 두 이름이 자리를 바꾼다 —
    /// 남들이 나를 그린 것은 「사람들이 그린 / **케빈**의 첫인상」,
    /// 내가 남들을 그린 것은 「**케빈**이 그린 / 사람들의 첫인상」.
    let mine: Bool
    /// 이번 내보내기에서 **한 쪽에 가장 많이 들어가는 장수.** 칸 크기를 이걸로 정한다.
    ///
    /// 이 장에 실린 장수로 칸을 정하면 같은 내보내기 안에서 쪽마다 그림 크기가 달라진다 —
    /// 열 장을 고르면 1쪽은 여섯 장이라 칸이 작고 2쪽은 네 장이라 칸이 커져,
    /// 재 보니 **3.2배** 차이가 났다. 두 장을 나란히 넘겨 보면 대번에 어긋나 보인다.
    /// 그래서 칸 크기는 쪽이 아니라 **내보내기 전체**가 정한다.
    let gridBasis: Int

    /// 지금 굽는 판형. 여섯 장이 안 될 때 격자가 쓰는 폭이 여기에 달렸다.
    @Environment(\.exportRatio) private var ratio

    /// 제목. 이름에만 밑줄이 그어지므로 이름이 어느 줄에 오는지에 따라 자리가 바뀐다.
    private var cardTitle: ExportCardTitle {
        mine
            ? ExportCardTitle(firstName: myName,
                              firstTail: "\(myName.subjectParticle) 그린",
                              secondName: "",
                              secondTail: "사람들의 첫인상")
            : ExportCardTitle(firstName: "",
                              firstTail: "사람들이 그린",
                              secondName: myName,
                              secondTail: "의 첫인상")
    }

    /// 한 장에 들어가는 최대 장수. Figma 가 2열 x 3행으로 여섯 칸을 둔다.
    static let perPage = 6

    var body: some View {
        ExportCard(title: cardTitle) {
            grid
        }
    }

    /// 그림 격자.
    ///
    /// Figma 의 여섯 그림은 크기가 제각각(55x85 ~ 104x126)인데, 이는 배치가 흩어져서가 아니라
    /// **디자이너가 그린 예시마다 획이 차지하는 범위가 달라서**다.
    /// 중심을 모아 보면 2열 x 3행 격자가 나온다 —
    /// 열 중심 134 / 265(간격 131), 행 중심 338 / 479 / 620(간격 141).
    private var grid: some View {
        let shown = Array(posts.prefix(Self.perPage))
        let layout = Self.layout(for: shown.count, basis: gridBasis, ratio: ratio)

        return ZStack(alignment: .topLeading) {
            ForEach(Array(shown.enumerated()), id: \.offset) { index, post in
                let ink = Self.ink(of: post, in: layout.cell)
                let center = layout.center(at: index, of: shown.count)
                Image(uiImage: ink.image)
                    .resizable()
                    .frame(width: ink.size.width, height: ink.size.height)
                    // 크기가 제각각이라 칸의 한가운데를 기준으로 놓는다.
                    .offset(x: center.x - ink.size.width / 2,
                            y: center.y - ink.size.height / 2)
            }
        }
    }

    /// 획이 차지한 만큼만 잘라 구운 그림과, 칸 안에서 차지할 크기.
    ///
    /// 캔버스(350x390) 통째로 그리면 여섯 칸이 모두 같은 크기가 되는데,
    /// 획이 구석에 조금 있는 그림은 칸의 1/4 만 차지해 인스타그램에서 보이지 않는다.
    /// Figma `iPhone 17 - 27` 의 여섯 예시도 55x85 ~ 104x126 으로 제각각이다 —
    /// 흩어 놓은 것이 아니라 **획 범위대로 잘라** 크기가 달라진 것이다.
    ///
    /// 그리드·상세·프로필은 `canvasImage()` 로 캔버스를 통째로 굽는다(`PKDrawing+Doodle` 주석).
    /// 거기서는 그린 사람이 잡은 자리가 그대로 남아야 하지만,
    /// 이 카드는 앱 밖으로 나가는 포스터라 여백을 버리는 쪽이 맞다.
    ///
    /// 캐시가 구워 둔 이미지를 잘라 늘리지 않는다. 그러면 흐려진다.
    /// `image(from:)` 으로 그 범위만 새로 구우면 선명도가 그대로다.
    @MainActor
    private static func ink(of post: Post, in cell: CGSize) -> (image: UIImage, size: CGSize) {
        let drawing = post.drawing
        let canvas = CGRect(origin: .zero, size: DoodleMetrics.canvasSize)
        let box = drawing.bounds.insetBy(dx: -inkMargin, dy: -inkMargin).intersection(canvas)

        // 획이 하나도 없으면 `bounds` 가 비어 있다. 잘라낼 것이 없으니 캔버스 그대로.
        guard !box.isNull, box.width > 0, box.height > 0 else {
            return (DoodleImageCache.image(for: post.drawingData), fitted(canvas.size, in: cell))
        }
        return (drawing.image(from: box, scale: 3), fitted(box.size, in: cell))
    }

    /// 칸 안에 맞춘 크기. 비율을 지키고, 캔버스를 통째로 그렸을 때보다 `maxUpscale` 배를 넘기지 않는다.
    ///
    /// 상한이 없으면 점 하나만 찍은 그림이 칸을 꽉 채워 획이 터무니없이 굵어 보인다.
    /// 상한을 두면 큰 그림은 칸을 채우고 작은 낙서는 커지되 여전히 작게 남는다 —
    /// Figma 예시의 들쭉날쭉함이 그 모습이다.
    private static func fitted(_ size: CGSize, in cell: CGSize) -> CGSize {
        let fit = min(cell.width / size.width, cell.height / size.height)
        let canvasFit = min(cell.width / DoodleMetrics.canvasSize.width,
                            cell.height / DoodleMetrics.canvasSize.height)
        let scale = min(fit, canvasFit * maxUpscale)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    // MARK: - 격자 자리

    /// 이 장에 실린 장수에 맞춘 격자. 칸 크기와 칸마다의 한가운데를 미리 계산해 둔다.
    private struct GridLayout {
        let cell: CGSize
        let centers: [CGPoint]

        func center(at index: Int, of count: Int) -> CGPoint {
            centers[Swift.min(index, centers.count - 1)]
        }
    }

    /// 장수와 판형에 맞춰 격자를 짠다.
    ///
    /// **칸이 가장 커지는 열 수**를 고른다.
    /// 2열에 못박아 두면 카드가 넓어져도 격자는 좁은 폭에 갇혀 가운데로 몰린다 —
    /// 1:1 로 여섯 장을 구우면 격자가 카드 폭의 **29%** 밖에 안 썼다.
    /// 6 = 2x3 = 3x2 이므로 카드가 가로로 길어지면 격자도 눕히면 된다(73%, 칸은 1.6배).
    ///
    /// 바꾸는 기준을 **1.1배**로 둔 것은 9:16 에서 세로 배치를 지키기 위해서다.
    /// 거기서는 3열이 2열보다 오히려 작아(칸 138 대 168) 저절로 2열이 남는다 —
    /// 판형을 손으로 가려내지 않아도 규칙 하나로 갈린다.
    ///
    /// 한때 **9:16 여섯 장만 Figma 자리(열 134/265, 행 338/479/620, 칸 126.5x141)에 못박아** 두었다.
    /// 그 도안이 402 프레임에 그려진 것이라 9:16 카드에서는 격자가 폭의 53% 밖에 쓰지 못했다.
    /// 자리를 계산에 맡기니 같은 2열 3행에 칸만 126.5 -> 167.8 로 커진다(+33%).
    ///
    /// 마지막 줄이 한 칸만 남으면 가운데로 모은다. 왼쪽에 붙여 두면 오른쪽이 휑하다.
    private static func layout(for count: Int, basis: Int, ratio: ExportRatio) -> GridLayout {
        let area = adaptiveArea(ratio: ratio)
        let columns = columnCount(for: basis, in: area)

        // 칸 크기는 이 장의 장수가 아니라 `basis` 가 정한다.
        // 이 장의 장수로 잡으면 아홉 장을 5·4 로 나눴을 때 1쪽은 세 줄, 2쪽은 두 줄이 되어
        // 칸이 271 과 416 으로 벌어진다 — 쪽을 고르게 나눠 놓고도 크기가 어긋난다.
        let cell = cellSize(for: basis, columns: columns, in: area)

        let n = max(count, 1)
        let inLine = min(columns, n)
        let rows = (n + inLine - 1) / inLine
        let gridHeight = CGFloat(rows) * cell.height + CGFloat(rows - 1) * gap
        let firstRowY = area.midY - gridHeight / 2 + cell.height / 2

        var centers: [CGPoint] = []
        for index in 0 ..< n {
            let row = index / inLine
            let inRow = index % inLine
            let inThisRow = min(inLine, n - row * inLine)
            let rowWidth = CGFloat(inThisRow) * cell.width + CGFloat(inThisRow - 1) * gap
            centers.append(CGPoint(
                x: area.midX - rowWidth / 2 + CGFloat(inRow) * (cell.width + gap) + cell.width / 2,
                y: firstRowY + CGFloat(row) * (cell.height + gap)
            ))
        }
        return GridLayout(cell: cell, centers: centers)
    }

    /// `basis` 장을 가장 크게 담는 열 수.
    ///
    /// 예전 규칙(2열)을 기준으로 삼고, 그보다 `columnGain` 배 넘게 커질 때만 바꾼다.
    /// 조금 커지는 정도로 열 수를 흔들면 장수가 하나 달라질 때마다 배치가 튄다.
    private static func columnCount(for basis: Int, in area: CGRect) -> Int {
        let items = max(basis, 1)
        let baseline = min(items, 2)
        let baselineWidth = cellSize(for: items, columns: baseline, in: area).width

        var best = baseline
        var bestWidth = baselineWidth
        for columns in 1 ... items where columns != baseline {
            let width = cellSize(for: items, columns: columns, in: area).width
            if width > bestWidth { best = columns; bestWidth = width }
        }
        return bestWidth > baselineWidth * columnGain ? best : baseline
    }

    /// `items` 장을 `columns` 열로 놓을 때 칸 하나의 크기. 캔버스 비율(350:390)을 지킨다.
    private static func cellSize(for items: Int, columns: Int, in area: CGRect) -> CGSize {
        let columns = max(columns, 1)
        let rows = (max(items, 1) + columns - 1) / columns
        let byWidth = (area.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
        let byHeight = (area.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
            * DoodleMetrics.canvasSize.width / DoodleMetrics.canvasSize.height
        let width = max(min(byWidth, byHeight), 1)
        return CGSize(
            width: width,
            height: width * DoodleMetrics.canvasSize.height / DoodleMetrics.canvasSize.width
        )
    }

    /// 열 수를 바꾸려면 칸이 이만큼은 커져야 한다.
    private static let columnGain: CGFloat = 1.1

    /// 격자가 쓸 수 있는 자리.
    ///
    /// 세로는 `ExportCardLayout` 의 본문 자리 그대로다 — 제목과 꼬리말에서 리듬(36)만큼 떨어진다.
    /// 가로는 카드 전체 폭에서 좌우 여백(28)을 남긴 만큼이다.
    /// `content` 좌표계가 곧 9:16 카드라 9:16 에서는 `contentLeft` 가 0 이고,
    /// 더 넓은 판형에서만 왼쪽으로 넘어가 x 가 음수로 시작한다.
    ///
    /// 9:16 에서는 세로가 먼저 차므로 이 599 가 곧 칸 크기를 정한다 — 칸 174x194.
    /// 판형이 넓어지면 이 자리도 같이 넓어져, 두 장을 1:1 로 구우면
    /// 칸이 9:16 의 두 배 가까이 커져 정사각형 판을 제대로 채운다.
    private static func adaptiveArea(ratio: ExportRatio) -> CGRect {
        let layout = ExportCardLayout(ratio: ratio)
        return CGRect(
            x: -layout.contentLeft + sideMargin,
            y: ExportCardLayout.bodyTop,
            width: layout.size.width - sideMargin * 2,
            height: ExportCardLayout.bodyHeight
        )
    }

    /// 좌우 여백. 세 카드가 함께 쓴다.
    private static let sideMargin = ExportCardLayout.sideMargin
    private static let gap: CGFloat = 8

    /// 획 굵기의 절반이 잘리지 않도록 잘라낼 범위를 조금 넓힌다.
    private static let inkMargin: CGFloat = 4
    /// 캔버스 통째로 그렸을 때보다 몇 배까지 키울지.
    private static let maxUpscale: CGFloat = 1.8
}
