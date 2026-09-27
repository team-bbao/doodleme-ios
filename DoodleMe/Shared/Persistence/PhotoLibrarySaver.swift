//
//  PhotoLibrarySaver.swift
//  DoodleMe
//

import Photos
import UIKit

/// 그림을 사진 앱에 저장한다.
///
/// 상세 화면(한 장)과 갤러리의 고르기(여러 장)가 같은 자리를 쓴다.
/// 예전에는 상세 화면 안에만 있어서, 갤러리에서 여러 장을 저장하려면 같은 코드를 한 벌 더
/// 두어야 했다 — 권한을 묻는 방식이나 실패했을 때 하는 말이 두 곳에서 갈릴 자리였다.
enum PhotoLibrarySaver {

    /// 저장을 마치고 사람에게 할 말.
    enum Outcome {
        /// 고른 것이 모두 들어갔다.
        case saved(count: Int)
        /// 일부만 들어갔다. 조용히 넘어가지 않는다.
        case partial(saved: Int, total: Int)
        case noPermission
        case failed(String)

        /// 확인창에 띄울 문구.
        var message: String {
            switch self {
            case .saved(let count):
                count == 1 ? "그림이 사진 앱에 저장됐어요." : "\(count)장이 사진 앱에 저장됐어요."
            case .partial(let saved, let total):
                "\(total)장 중 \(saved)장만 저장됐어요."
            case .noPermission:
                "사진 접근 권한이 없어 저장하지 못했어요. 설정에서 허용해주세요."
            case .failed(let reason):
                "저장에 실패했어요: \(reason)"
            }
        }
    }

    /// 사진 앱에 남길 한 장. **화면에서 보고 있던 면**이 그대로 들어간다.
    ///
    /// 카드는 앞뒤가 있고 두 면이 담는 것이 다르다.
    /// 앞을 보며 저장을 누른 사람은 그림을, 뒤를 보며 누른 사람은 한마디를 기대한다.
    /// 그래서 한 장에 둘을 붙이지 않고 **누른 면만** 굽는다.
    enum Face {
        /// 앞면 — 그린 그림.
        case drawing(Data)
        /// 뒷면 — 한마디. 화면과 같이 상대와 얼굴이 위에 함께 선다.
        ///
        /// - Parameter avatar: 상대가 함께 보낸 프로필 그림. 없으면 이름으로 고른 얼굴을 쓴다.
        case message(text: String, counterpart: String, suffix: String, avatar: Data?)
    }

    /// 한 장. 면이 무엇이든 **아래에는 그린 날짜**가 선다.
    struct Item {
        let face: Face
        let date: Date
    }

    /// 사진 앱에 넣는다.
    ///
    /// **권한은 맨 앞에서 한 번만 묻는다.** 장마다 물으면 열 장을 고른 사람에게
    /// 같은 질문이 열 번 간다.
    ///
    /// 한 장이 실패해도 멈추지 않고 나머지를 마저 넣는다.
    /// 열 장 중 아홉 장이 들어갈 수 있는데 첫 장에서 그만두면 아홉 장을 잃는다.
    @MainActor
    static func save(_ items: [Item]) async -> Outcome {
        guard !items.isEmpty else { return .saved(count: 0) }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return .noPermission }

        var saved = 0
        var firstError: String?

        for item in items {
            guard let data = snapshot(of: item) else {
                firstError = firstError ?? "이미지를 만들지 못했어요."
                continue
            }
            do {
                try await write(data)
                saved += 1
            } catch {
                firstError = firstError ?? error.localizedDescription
            }
        }

        if saved == items.count { return .saved(count: saved) }
        if saved > 0 { return .partial(saved: saved, total: items.count) }
        return .failed(firstError ?? "알 수 없는 까닭")
    }

    /// 사진 앱에 남길 이미지.
    ///
    /// **종이는 담지 않는다.** 화면의 메모지에는 결과 그늘과 접힌 모서리가 있지만
    /// 사진첩에 남는 건 그림이지 종이가 아니다. 흰 바탕에 내용만 얹는다.
    ///
    /// 두 면이 **같은 크기(카드 362x396)** 로 나온다. 앞뒤를 따로 저장해도
    /// 사진첩에서 나란히 놓였을 때 한 벌로 보인다.
    ///
    /// SwiftUI `ImageRenderer` 로 굽지 않는다. 카드 뷰가 `DoodleImageView` 를 쓰는데
    /// 그 뷰는 `.task` 로 그림을 늦게 채우고, 화면에 붙지 않은 뷰에서는 그 `task` 가 돌지 않는다.
    /// 그대로 구우면 획 없는 흰 종이만 저장된다 — 캐시가 이미 구워 둔 그림을 직접 얹는다.
    @MainActor
    static func snapshot(of item: Item) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        // 사진에 투명한 자리를 남기지 않는다. 흰 바탕이 전부 채운다.
        format.opaque = true

        let image = UIGraphicsImageRenderer(size: cardSize, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: cardSize))

            switch item.face {
            case .drawing(let data):
                draw(drawing: data)
            case .message(let text, let counterpart, let suffix, let avatar):
                draw(message: text, counterpart: counterpart, suffix: suffix, avatar: avatar)
            }

            draw(date: item.date)
        }
        return image.pngData()
    }

    // MARK: - 앞면

    /// 그림을 날짜 위 칸에 **비율 그대로** 앉힌다.
    ///
    /// 화면에서는 그림이 카드를 꽉 채우지만 여기서는 아래를 날짜에 내준다.
    /// 늘려 채우면 그린 모양이 달라지므로, 남는 쪽을 여백으로 두고 가운데에 맞춘다.
    private static func draw(drawing data: Data) {
        let room = CGRect(x: 0, y: 0, width: cardSize.width, height: cardSize.height - dateBlock)
        let canvas = DoodleMetrics.canvasSize
        let scale = min(room.width / canvas.width, room.height / canvas.height)
        let size = CGSize(width: canvas.width * scale, height: canvas.height * scale)

        DoodleImageCache.image(for: data).draw(in: CGRect(
            x: room.midX - size.width / 2,
            y: room.midY - size.height / 2,
            width: size.width,
            height: size.height
        ))
    }

    // MARK: - 뒷면

    /// 한마디를 카드 한가운데에, 상대는 왼쪽 위에 — 화면의 뒷면과 같은 자리다.
    private static func draw(message text: String,
                             counterpart: String,
                             suffix: String,
                             avatar: Data?) {
        if !counterpart.isEmpty {
            draw(avatar: avatar, for: counterpart)

            let name = NSMutableAttributedString(string: counterpart, attributes: [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: UIColor(white: 0x42 / 255, alpha: 1),
            ])
            if !suffix.isEmpty {
                name.append(NSAttributedString(string: " " + suffix, attributes: [
                    .font: UIFont.systemFont(ofSize: 16),
                    .foregroundColor: UIColor(white: 0x6F / 255, alpha: 1),
                ]))
            }
            // 글의 밑선이 아니라 **중심**을 얼굴 원의 중심에 맞춘다.
            let height = name.size().height
            name.draw(at: CGPoint(x: sideMargin + avatarDiameter + avatarGap,
                                  y: topMargin + (avatarDiameter - height) / 2))
        }

        // 한마디는 **빈 글이어도 자리를 비워 두지 않는다.** 뒷면을 저장한 사람은
        // 거기 무엇이 있었는지를 남기려는 것이라, 화면과 같은 말을 그대로 적는다.
        let body = attributed(text.isEmpty ? "(텍스트 없음)" : text,
                              font: .doodleHandwriting(size: messageFontSize),
                              color: UIColor(white: 0x42 / 255, alpha: 1),
                              lineHeight: messageLineHeight)
        let width = messageWidth
        let height = self.height(of: body, width: width)
        body.draw(with: CGRect(x: cardSize.width / 2 - width / 2,
                               y: cardSize.height / 2 - height / 2,
                               width: width, height: height),
                  options: .usesLineFragmentOrigin, context: nil)
    }

    /// 얼굴 원. 받은 프로필이 있으면 그것을, 없으면 이름으로 고른 낙서를 쓴다.
    /// 고르는 규칙은 화면과 같아서, 같은 사람에게는 늘 같은 얼굴이 붙는다.
    private static func draw(avatar data: Data?, for name: String) {
        let circle = CGRect(x: sideMargin, y: topMargin,
                            width: avatarDiameter, height: avatarDiameter)
        let path = UIBezierPath(ovalIn: circle)

        UIColor.white.setFill()
        path.fill()
        UIColor(white: 0xE1 / 255, alpha: 1).setStroke()
        path.lineWidth = 1
        path.stroke()

        if let data {
            // 받은 프로필은 원을 꽉 채운다. 화면에서도 그렇게 둔다.
            UIGraphicsGetCurrentContext()?.saveGState()
            path.addClip()
            DoodleImageCache.image(for: data).draw(in: circle)
            UIGraphicsGetCurrentContext()?.restoreGState()
        } else {
            let glyph = UIImage(resource: PeerAvatarPalette.image(for: name))
            let side: CGFloat = 30
            glyph.draw(in: CGRect(x: circle.midX - side / 2, y: circle.midY - side / 2,
                                  width: side, height: side))
        }
    }

    // MARK: - 두 면이 함께 쓰는 것

    /// 그린 날짜. **두 면 모두** 같은 자리에 같은 모양으로 선다.
    private static func draw(date: Date) {
        let text = attributed(date.formatted(date: .abbreviated, time: .omitted),
                              font: .systemFont(ofSize: 12),
                              color: UIColor(white: 0x82 / 255, alpha: 1))
        let height = self.height(of: text, width: cardSize.width)
        text.draw(with: CGRect(x: 0, y: cardSize.height - dateBottom - height,
                               width: cardSize.width, height: height),
                  options: .usesLineFragmentOrigin, context: nil)
    }

    /// 가운데 맞춘 글. 행높이를 주면 글꼴 기본값 대신 그 높이로 잡는다 —
    /// 손글씨체는 세로 여백이 넉넉해 그냥 두면 디자인보다 한참 벌어진다.
    private static func attributed(_ text: String,
                                   font: UIFont,
                                   color: UIColor,
                                   lineHeight: CGFloat? = nil) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        if let lineHeight {
            paragraph.minimumLineHeight = lineHeight
            paragraph.maximumLineHeight = lineHeight
        }
        return NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ])
    }

    private static func height(of text: NSAttributedString, width: CGFloat) -> CGFloat {
        ceil(text.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                               options: [.usesLineFragmentOrigin, .usesFontLeading],
                               context: nil).height)
    }

    // 화면의 카드(`PostDetailView`)에서 가져온 치수다. 한쪽만 고치면 저장본이 화면과 어긋난다.
    private static let cardSize = CGSize(width: 362, height: 396)
    private static let messageFontSize: CGFloat = 40
    private static let messageLineHeight: CGFloat = 44
    private static let messageWidth: CGFloat = 253
    private static let avatarDiameter: CGFloat = 55
    private static let avatarGap: CGFloat = 13
    private static let sideMargin: CGFloat = 20
    private static let topMargin: CGFloat = 19
    private static let dateBottom: CGFloat = 27

    /// 날짜가 차지하는 아래 칸. 앞면의 그림은 이 위까지만 쓴다.
    private static let dateBlock: CGFloat = 27 + 15

    /// 사진 앱에 실제로 쓰는 부분.
    ///
    /// 화면 밖으로 꺼내 격리를 끊어야 한다.
    /// `View` 안에 두면 메인 액터에 묶이고 넘기는 클로저도 함께 묶이는데,
    /// `performChanges` 는 PhotoKit 이 **자기 큐**에서 그 클로저를 부른다.
    /// 그러면 Swift 6 이 "여기는 메인이 아니다" 하고 앱을 끊는다 —
    /// 저장 버튼을 누를 때마다 `EXC_BREAKPOINT` 로 튕기던 것이 이것이었다.
    nonisolated private static func write(_ data: Data) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
        }
    }
}
