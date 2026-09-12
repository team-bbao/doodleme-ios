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
        let layout = Self.layout(for: shown.count)

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

    /// 장수에 맞춰 격자를 짠다.
    ///
    /// **여섯 장이면 Figma 그대로다.** 디자이너가 잡아 둔 자리가 있으니 건드리지 않는다 —
    /// 열 중심 134 / 265, 행 중심 338 / 479 / 620.
    ///
    /// 그보다 적으면 남는 줄을 없애고 **칸을 키운다.**
    /// 여섯 칸 자리를 그대로 두면 세 장일 때 아래 한 줄이 통째로 비고 그림은 칸을 제대로 못 채운다 —
    /// 인스타그램에서 작게 보면 뭘 그렸는지 알아볼 수 없다.
    /// 넓어진 카드 폭(9:16 으로 490)까지 함께 쓰므로 세 장이면 칸이 **1.6배** 커진다.
    ///
    /// 마지막 줄이 한 칸만 남으면 가운데로 모은다. 왼쪽에 붙여 두면 오른쪽이 휑하다.
    private static func layout(for count: Int) -> GridLayout {
        guard count < perPage else {
            return GridLayout(
                cell: figmaCell,
                centers: figmaRowCenters.flatMap { y in
                    figmaColumnCenters.map { CGPoint(x: $0, y: y) }
                }
            )
        }

        let n = max(count, 1)
        let columns = min(n, 2)
        let rows = (n + columns - 1) / columns

        let byWidth = (adaptiveArea.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
        let byHeight = (adaptiveArea.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
            * DoodleMetrics.canvasSize.width / DoodleMetrics.canvasSize.height
        let width = min(byWidth, byHeight)
        let cell = CGSize(
            width: width,
            height: width * DoodleMetrics.canvasSize.height / DoodleMetrics.canvasSize.width
        )

        let gridHeight = CGFloat(rows) * cell.height + CGFloat(rows - 1) * gap
        let firstRowY = adaptiveArea.midY - gridHeight / 2 + cell.height / 2

        var centers: [CGPoint] = []
        for index in 0 ..< n {
            let row = index / columns
            let inRow = index % columns
            let inThisRow = min(columns, n - row * columns)
            let rowWidth = CGFloat(inThisRow) * cell.width + CGFloat(inThisRow - 1) * gap
            centers.append(CGPoint(
                x: adaptiveArea.midX - rowWidth / 2 + CGFloat(inRow) * (cell.width + gap) + cell.width / 2,
                y: firstRowY + CGFloat(row) * (cell.height + gap)
            ))
        }
        return GridLayout(cell: cell, centers: centers)
    }

    /// 여섯 장이 안 될 때 격자가 쓸 수 있는 자리.
    ///
    /// 가로는 **카드 전체 폭**(9:16 으로 넓힌 490)에서 좌우 30 씩 남긴 만큼이다.
    /// `content` 좌표계는 402 라 왼쪽으로 넘어가므로 x 가 음수로 시작한다.
    /// 세로는 제목 아래(268)에서 꼬리말 위(740)까지 — Figma 가 쓰던 690 보다 50 더 내려간다.
    private static let adaptiveArea = CGRect(
        x: -ExportCardLayout.contentLeft + sideMargin,
        y: 268,
        width: ExportCardLayout.size.width - sideMargin * 2,
        height: 740 - 268
    )

    /// Figma `iPhone 17 - 27` 의 열·행 중심.
    private static let figmaColumnCenters: [CGFloat] = [134, 265]
    private static let figmaRowCenters: [CGFloat] = [338, 479, 620]

    private static let sideMargin: CGFloat = 30
    private static let gap: CGFloat = 8

    /// 칸 하나. 행 간격(141)을 넘지 않고 캔버스 비율(350:390)을 지킨다.
    private static let figmaCell = CGSize(width: 141 * 350 / 390, height: 141)

    /// 획 굵기의 절반이 잘리지 않도록 잘라낼 범위를 조금 넓힌다.
    private static let inkMargin: CGFloat = 4
    /// 캔버스 통째로 그렸을 때보다 몇 배까지 키울지.
    private static let maxUpscale: CGFloat = 1.8
}
