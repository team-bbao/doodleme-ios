//
//  ExportDrawingsCard.swift
//  DoodleMe
//

import PencilKit
import SwiftUI

/// 받은 그림 여러 장을 한 장에 모아 내보내는 카드. Figma 최종시안 `424:1795`(`424:1689` 이 칸 자리를 표시한 판).
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
    /// 이번 내보내기의 **섞기 씨앗.** 같은 그림을 골라도 열 때마다 달라진다.
    ///
    /// 카드가 스스로 뽑지 않고 밖에서 받는다. 뷰는 몸통이 여러 번 다시 그려지는데
    /// 그때마다 새로 뽑으면 **미리보기와 구운 파일이 어긋난다** —
    /// 화면에서 본 배치와 인스타에 올라가는 배치가 다른 그림이 된다.
    /// 내보내기 화면을 여는 쪽이 한 번 뽑아 들고 있는다.
    let shuffle: UInt64
    /// 이번 내보내기에서 **한 쪽에 가장 많이 들어가는 장수.** 칸 크기를 이걸로 정한다.
    ///
    /// 이 장에 실린 장수로 칸을 정하면 같은 내보내기 안에서 쪽마다 그림 크기가 달라진다 —
    /// 열 장을 고르면 1쪽은 여섯 장이라 칸이 작고 2쪽은 네 장이라 칸이 커져,
    /// 재 보니 **3.2배** 차이가 났다. 두 장을 나란히 넘겨 보면 대번에 어긋나 보인다.
    /// 그래서 칸 크기는 쪽이 아니라 **내보내기 전체**가 정한다.
    let gridBasis: Int

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
        // 제목이 한 장 카드보다 28 위에 선다. 여섯 칸을 담느라 본문이 그만큼 더 필요하다.
        ExportCard(title: cardTitle, titleTop: ExportCardLayout.gridTitleTop) {
            grid
        }
    }

    /// 그림 격자.
    ///
    /// 최종시안의 여섯 그림은 크기가 제각각(102x111 ~ 141x154)인데, 이는 배치가 흩어져서가 아니라
    /// **디자이너가 그린 예시마다 획이 차지하는 범위가 달라서**다.
    /// 중심을 모아 보면 2열 x 3행 격자가 나온다 —
    /// 열 중심 125.4 / 273.5(간격 148), 행 중심 296.9 / 462.7 / 611.6.
    ///
    /// 다만 **딱 맞는 격자는 아니다.** 여섯 칸이 저마다 조금씩 어긋나 있고 기울어져 있다 —
    /// 종이에 손으로 붙인 것처럼 보이게 하려는 것이다.
    private var grid: some View {
        let shown = Array(posts.prefix(Self.perPage))
        let slots = Self.slots(for: shown, basis: gridBasis, shuffle: shuffle)

        return ZStack(alignment: .topLeading) {
            ForEach(Array(shown.enumerated()), id: \.offset) { index, post in
                let slot = slots[index]
                let ink = Self.ink(of: post, in: slot)
                // 작게 뽑힌 그림은 칸 안에 틈이 남는다. 그 틈 안에서 자리도 흩뿌린다 —
                // 칸을 벗어나지 않으므로 옆 그림과 겹칠 일이 없다.
                let spread = Self.rotatedSize(ink.size, degrees: slot.degrees)
                let left = slot.box.minX + (slot.box.width - spread.width) * slot.drift.x
                let top = slot.box.minY + (slot.box.height - spread.height) * slot.drift.y

                Image(uiImage: ink.image)
                    .resizable()
                    .frame(width: ink.size.width, height: ink.size.height)
                    .rotationEffect(.degrees(slot.degrees))
                    // 돌림은 한가운데를 축으로 돌고 자리를 바꾸지 않으므로,
                    // 돌리기 전 그림을 테두리 한가운데에 놓으면 돌린 뒤에도 한가운데에 남는다.
                    .offset(x: left + (spread.width - ink.size.width) / 2,
                            y: top + (spread.height - ink.size.height) / 2)
            }
        }
    }

    // MARK: - 칸

    /// 그림 한 장이 앉는 자리.
    ///
    /// `box` 는 **돌린 뒤의 테두리**다. 그림은 여기를 넘지 않는다 —
    /// Figma 가 칸마다 투명한 상자를 두어 서로 침범하지 않게 해 둔 것과 같은 뜻이다.
    private struct Slot {
        let box: CGRect
        let degrees: Double
        /// 칸을 꽉 채웠을 때 대비 몇 배로 그릴지.
        let scale: CGFloat
        /// 남는 틈 안에서 어디에 앉을지. 0 이면 왼쪽·위, 1 이면 오른쪽·아래.
        let drift: CGPoint
    }

    /// `size` 를 `degrees` 만큼 돌렸을 때의 바깥 사각형.
    private static func rotatedSize(_ size: CGSize, degrees: Double) -> CGSize {
        let radians = abs(degrees) * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)
        return CGSize(width: size.width * cosine + size.height * sine,
                      height: size.width * sine + size.height * cosine)
    }

    /// 최종시안이 정한 여섯 칸. `424:1799` ~ `424:1814` 에서 그대로 옮겼다.
    ///
    /// **돌린 뒤의 테두리다.** Figma 는 기울인 그림의 바깥 사각형을 자리로 적어 두는데,
    /// 그 여섯이 서로 11~22 씩 떨어져 **한 번도 겹치지 않는다.**
    /// 칸을 고르게 나눠 놓고 흩뿌리는 방식으로는 이 여백이 나오지 않는다 —
    /// 흩뿌린 만큼 옆 칸으로 넘어가기 때문이다. 그래서 도안의 자리를 그대로 쓴다.
    ///
    /// 차례는 격자가 채우는 차례(왼쪽 위 -> 오른쪽 -> 다음 줄)에 맞췄다 —
    /// 도안에서는 마지막 줄의 왼쪽 칸(`Frame 61`)이 오른쪽 칸보다 뒤에 그려져 있다.
    /// 기울기는 여기 없다 — 그림마다 새로 뽑는다. 자리와 크기만 도안에서 가져온다.
    private static let designSlots: [CGRect] = [
        CGRect(x: 49,  y: 237,    width: 137.034, height: 146.753),
        CGRect(x: 201, y: 210,    width: 137.034, height: 146.753),
        CGRect(x: 64,  y: 396,    width: 137.034, height: 146.753),
        CGRect(x: 215, y: 379,    width: 141.248, height: 154.000),
        CGRect(x: 73,  y: 554.01, width: 106.347, height: 115.133),
        CGRect(x: 201, y: 544,    width: 128.624, height: 135.005),
    ]

    /// 그림마다의 자리·크기·기울기.
    ///
    /// **크기와 방향이 그림마다 다르다.** 최종시안의 여섯이 저마다 다른 크기·각도인데,
    /// 그 여섯 값을 못박아 두면 누가 무엇을 고르든 늘 같은 모양으로 나온다.
    /// 그래서 값을 정해 두지 않고 **그림에서 끌어낸다.**
    ///
    /// **둘이 같은 값을 받지 않는다.** 그냥 난수를 뽑으면 여섯이 비슷하게 몰릴 수 있어
    /// 「손으로 붙인 것 같은」 인상이 사라진다. 범위를 장수만큼 칸으로 나눠 한 칸씩 나눠 주고,
    /// **누가 어느 칸을 받을지만** 섞는다.
    ///
    /// **한 번 열린 동안에는 바뀌지 않는다.** 씨앗을 밖에서 받는 까닭이 그것이다.
    private static func slots(for posts: [Post], basis: Int, shuffle: UInt64) -> [Slot] {
        let bases = baseSlots(for: posts.count, basis: basis)
        let tilts = spread(count: posts.count, over: tiltRange, seed: shuffle)
        let scales = spread(count: posts.count, over: scaleRange, seed: scrambled(shuffle))

        var state = scrambled(shuffle &+ 0x5851_F42D_4C95_7F2D)
        return bases.indices.map { index in
            state = scrambled(state)
            let x = fraction(state)
            state = scrambled(state)
            let y = fraction(state)
            return Slot(box: bases[index].insetBy(dx: safety, dy: safety),
                        degrees: tilts[index],
                        scale: scales[index],
                        drift: CGPoint(x: x, y: y))
        }
    }

    /// 칸 안쪽으로 물리는 안전 여백.
    ///
    /// 계산으로는 딱 맞는데 구워 보면 획이 3 쯤 삐져나왔다 —
    /// 획을 그린 그림을 돌리고 줄이는 동안 가장자리가 번지기 때문이다.
    /// 칸 사이가 11~22 라 겹치지는 않지만, 「칸을 넘지 않는다」 를 계산이 아니라
    /// 구운 결과로 지키려고 이만큼 물려 둔다.
    private static let safety: CGFloat = 3

    /// 기울기와 크기가 흩어지는 범위.
    ///
    /// 최종시안의 여섯은 기울기 -6.33 ~ +16.19, 폭 106 ~ 141(가장 큰 것의 0.75배)이었다.
    /// 그 폭을 좌우 고르게 펴되 **도안보다 넓게** 잡는다 —
    /// 도안 그대로 두면 차이가 눈에 잘 띄지 않아 여섯이 비슷하게 읽혔다.
    /// 한쪽으로만 기울면 종이가 돌아간 것처럼 보이므로 좌우를 같게 둔다.
    ///
    /// 크기는 **돌림과 곱해진다.** 15도 기울이면 바깥 사각형이 커져 그림이 0.82 배로 줄므로,
    /// 가장 작게 뽑힌 그림은 칸의 0.53 배까지 내려간다 — 「작고 크고」가 분명히 갈린다.
    private static let tiltRange: ClosedRange<Double> = -15 ... 15
    private static let scaleRange: ClosedRange<Double> = 0.65 ... 1.0

    /// 범위를 `count` 칸으로 나눠 한 칸씩 나눠 준다. **두 그림이 같은 값을 받지 않는다.**
    ///
    /// 칸 안에서 조금 흔들되 칸의 60% 를 넘지 않는다 — 이웃 칸과 섞이지 않을 만큼이다.
    /// 그런 뒤 순서를 섞어 어느 그림이 어느 칸을 받을지 정한다.
    private static func spread(count: Int,
                               over range: ClosedRange<Double>,
                               seed: UInt64) -> [Double] {
        guard count > 1 else { return [(range.lowerBound + range.upperBound) / 2] }

        let step = (range.upperBound - range.lowerBound) / Double(count - 1)
        var state = seed
        var values = (0 ..< count).map { index -> Double in
            state = scrambled(state)
            return range.lowerBound + step * Double(index) + (fraction(state) - 0.5) * step * 0.6
        }

        // 피셔-예이츠. 값은 그대로 두고 받는 차례만 바꾼다.
        for index in stride(from: values.count - 1, to: 0, by: -1) {
            state = scrambled(state)
            values.swapAt(index, Int(state % UInt64(index + 1)))
        }
        return values
    }

    /// SplitMix64. 씨앗 하나를 고르게 흩어진 수로 바꾼다.
    private static func scrambled(_ value: UInt64) -> UInt64 {
        var z = value &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0 이상 1 미만.
    private static func fraction(_ value: UInt64) -> Double {
        Double(value >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    /// 크기와 기울기를 얹기 전의 칸.
    ///
    /// **여섯 장이면 도안의 자리를 그대로 쓴다.** 디자이너가 이미 풀어 놓은 답이다.
    /// 그보다 적으면 도안에 정답이 없으므로 고르게 나눈 격자를 쓰되,
    /// 흩뿌린 만큼 칸을 안쪽으로 좁혀 **옆 칸을 넘지 않게** 한다.
    private static func baseSlots(for count: Int, basis: Int) -> [CGRect] {
        guard count != designSlots.count else { return designSlots }

        let layout = layout(for: count, basis: basis)
        return (0 ..< count).map { index in
            let scatter = Self.scatter[index % Self.scatter.count]
            let center = layout.center(at: index, of: count)
            let dx = scatter.dx * layout.cell.width
            let dy = scatter.dy * layout.cell.height
            // 한가운데를 dx 옮기면 칸 안에 남는 반폭은 그만큼 준다.
            let size = CGSize(width: layout.cell.width - 2 * abs(dx),
                              height: layout.cell.height - 2 * abs(dy))
            return CGRect(x: center.x + dx - size.width / 2,
                          y: center.y + dy - size.height / 2,
                          width: size.width,
                          height: size.height)
        }
    }

    /// 칸마다의 어긋남. 최종시안에서 잰 값을 **칸 크기에 대한 비율**로 적었다.
    private static let scatter: [(dx: CGFloat, dy: CGFloat)] = [
        (-0.058,  0.092),
        (-0.029, -0.092),
        ( 0.052,  0.046),
        ( 0.088, -0.046),
        ( 0.006,  0.000),
        (-0.060,  0.000),
    ]

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
    private static func ink(of post: Post, in slot: Slot) -> (image: UIImage, size: CGSize) {
        let drawing = post.drawing
        let canvas = CGRect(origin: .zero, size: DoodleMetrics.canvasSize)
        let box = drawing.bounds.insetBy(dx: -inkMargin, dy: -inkMargin).intersection(canvas)

        // 획이 하나도 없으면 `bounds` 가 비어 있다. 잘라낼 것이 없으니 캔버스 그대로.
        guard !box.isNull, box.width > 0, box.height > 0 else {
            return (DoodleImageCache.image(for: post.drawingData), fitted(canvas.size, in: slot))
        }
        return (drawing.image(from: box, scale: 3), fitted(box.size, in: slot))
    }

    /// 칸 안에 맞춘 크기. **돌린 뒤의 테두리**가 칸을 넘지 않게 잡는다.
    ///
    /// 돌리기 전 크기로만 맞추면 안 된다. 폭 w · 높이 h 짜리를 t 만큼 기울이면
    /// 바깥 사각형이 `w·cos t + h·sin t` 로 넓어지는데, 6도만 기울여도 12% 가 늘어
    /// 옆 칸을 침범한다 — 구운 카드에서 파도와 소용돌이가 맞붙었다.
    ///
    /// 비율을 지키고, 캔버스를 통째로 그렸을 때보다 `maxUpscale` 배를 넘기지 않는다.
    /// 상한이 없으면 점 하나만 찍은 그림이 칸을 꽉 채워 획이 터무니없이 굵어 보인다.
    /// 상한을 두면 큰 그림은 칸을 채우고 작은 낙서는 커지되 여전히 작게 남는다 —
    /// Figma 예시의 들쭉날쭉함이 그 모습이다.
    private static func fitted(_ size: CGSize, in slot: Slot) -> CGSize {
        let radians = abs(slot.degrees) * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)
        // 높이 ÷ 폭. 이 비를 지키면서 폭을 얼마나 키울 수 있는지 푼다.
        let ratio = size.height / size.width

        let byWidth = slot.box.width / (cosine + ratio * sine)
        let byHeight = slot.box.height / (sine + ratio * cosine)

        let canvas = DoodleMetrics.canvasSize
        let canvasRatio = canvas.height / canvas.width
        let canvasWidth = min(slot.box.width / (cosine + canvasRatio * sine),
                              slot.box.height / (sine + canvasRatio * cosine))
        // 캔버스를 통째로 그렸을 때의 배율을 이 그림에 옮겨 상한으로 삼는다.
        let ceiling = canvasWidth / canvas.width * maxUpscale * size.width

        let width = min(byWidth, byHeight, ceiling) * slot.scale
        return CGSize(width: width, height: width * ratio)
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
    /// **칸이 가장 커지는 열 수**를 고른다. 장수가 적을 때 2열에 못박아 두면
    /// 칸이 쓸데없이 작아진다 — 두 장이면 1열로 세워 놓는 편이 훨씬 크게 담긴다.
    /// 바꾸는 기준을 **1.1배**로 둔 것은 조금 커지는 정도로 배치가 튀지 않게 하려는 것이다.
    ///
    /// 여섯 장이면 자연히 2열 3행이 남는다 — 3열로 놓으면 칸이 96 으로 줄어 오히려 작아진다.
    /// 그때 나오는 칸(133.7x149)과 자리(열 130/272, 행 294.5/451.5/608.5)가
    /// 최종시안(칸 137x147, 열 125/274, 행 297/463/612)과 최대 11 안에서 겹친다.
    ///
    /// 마지막 줄이 한 칸만 남으면 가운데로 모은다. 왼쪽에 붙여 두면 오른쪽이 휑하다.
    private static func layout(for count: Int, basis: Int) -> GridLayout {
        let area = Self.area
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

    /// 격자가 쓸 수 있는 자리. 최종시안의 여섯 칸이 그 안에 든다.
    ///
    /// 세로는 `ExportCardLayout` 의 본문 자리 그대로고,
    /// 가로는 **402 짜리 도안 안에서** 좌우 49 를 남긴 만큼이다.
    private static let area = CGRect(
        x: sideInset,
        y: ExportCardLayout.bodyTop,
        width: ExportCardLayout.contentWidth - sideInset * 2,
        height: ExportCardLayout.bodyHeight
    )

    /// 격자가 남기는 좌우 여백. 최종시안의 왼쪽 첫 칸이 49 에서 시작한다.
    private static let sideInset: CGFloat = 49
    private static let gap: CGFloat = 8

    /// 획 굵기의 절반이 잘리지 않도록 잘라낼 범위를 조금 넓힌다.
    private static let inkMargin: CGFloat = 4
    /// 캔버스 통째로 그렸을 때보다 몇 배까지 키울지.
    private static let maxUpscale: CGFloat = 1.8
}
