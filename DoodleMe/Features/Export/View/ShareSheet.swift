//
//  ShareSheet.swift
//  DoodleMe
//

import SwiftUI
import UIKit

/// 시스템 공유 시트를 연다.
///
/// **`ShareLink` 를 쓰지 않는 이유는 하나다 — 우리 항목을 끼워 넣을 수 없어서다.**
/// `ShareLink` 는 넘길 것만 받고 `applicationActivities` 를 받지 않아,
/// 「인스타그램 스토리」 칸(`InstagramStoryActivity`)을 시트 안에 세울 길이 없다.
///
/// `UIViewControllerRepresentable` 로 감싸 `.sheet` 에 넣지 않는다.
/// 그러면 시트 안에 시트가 들어가 손잡이가 둘이 되고 높이도 스스로 잡지 못한다.
/// 그냥 **맨 위에 떠 있는 화면이 직접 띄우게** 한다 — 아이폰에서 늘 보던 그 모양이 나온다.
@MainActor
enum ShareSheet {

    /// - Parameters:
    ///   - items: 넘길 것들. 미리보기는 구운 PNG 의 파일 주소를 넘긴다.
    ///   - story: 인스타그램 스토리로 보낼 **9:16 그림.** 없으면 그 칸이 서지 않는다.
    ///   - anchor: 아이패드에서 팝오버가 붙을 자리. 화면 좌표다.
    static func present(_ items: [Any], story: Data? = nil, anchor: CGRect? = nil) {
        guard let top = topViewController else { return }

        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: [InstagramStoryActivity(story: story)]
        )

        // **아이패드는 붙을 자리를 주지 않으면 그 자리에서 앱이 끊긴다.**
        // 알려 준 자리가 없으면 화면 위쪽 한가운데에 붙이고 화살표는 숨긴다.
        if let popover = controller.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = anchor ?? CGRect(x: top.view.bounds.midX,
                                                  y: top.view.bounds.minY + 80,
                                                  width: 1, height: 1)
            if anchor == nil { popover.permittedArrowDirections = [] }
        }

        top.present(controller, animated: true)
    }

    /// 지금 화면 맨 위에 떠 있는 것.
    ///
    /// 내보내기 미리보기는 `fullScreenCover` 로 떠 있어 루트가 아니다.
    /// 루트에 대고 띄우면 「이미 무언가를 띄우고 있다」며 아무 일도 일어나지 않는다.
    private static var topViewController: UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        guard var top = scene?.keyWindow?.rootViewController else { return nil }
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
