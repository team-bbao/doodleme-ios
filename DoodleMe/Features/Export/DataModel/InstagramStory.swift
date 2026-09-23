//
//  InstagramStory.swift
//  DoodleMe
//

import UIKit

/// 구운 카드를 **인스타그램 스토리 편집기로 곧장** 넘긴다.
///
/// 메타 「Sharing to Stories」 가 정한 길이다. 시스템 공유 시트에도 인스타그램이
/// 뜨지만 거기서는 「스토리」·「게시물」·「메시지」를 한 번 더 골라야 하고,
/// 목록에서 인스타그램을 찾는 일도 사람 몫이다.
/// 이 카드는 **스토리에 올리려고 만든 것**이라 그 한 자리로 바로 보낸다.
///
/// 그림은 주소에 실리지 않는다. **붙임판에 얹어 두면 인스타그램이 꺼내 간다** —
/// 메타가 정한 방식이고, 그래서 여는 것과 담는 것이 한 몸으로 붙어 있다.
@MainActor
enum InstagramStory {

    /// 스토리 편집기를 여는 주소.
    private static let share = URL(string: "instagram-stories://share")!

    /// 보낼 수 있는 상태인지. **둘 다 갖춰져야 한다.**
    ///
    /// ① 기기에 인스타그램이 있어야 한다.
    /// `Info.plist` 의 `LSApplicationQueriesSchemes` 에 `instagram-stories` 가 적혀 있어야
    /// 물어볼 수 있다 — 없으면 깔려 있어도 iOS 가 늘 「없다」고 답한다.
    ///
    /// ② **페이스북 앱 ID 가 있어야 한다.**
    /// 2023년 1월부터 메타가 요구한다. 없이 열면 인스타그램이 열리기는 하는데
    /// 「회원님이 공유한 앱은 현재 스토리에 공유하는 것을 지원하지 않습니다」 라는 오류만 뜬다 —
    /// 그럴 바에는 칸을 내지 않는 편이 낫다.
    static var isAvailable: Bool {
        appID != nil && UIApplication.shared.canOpenURL(share)
    }

    /// `Info.plist` 에 적어 둔 페이스북 앱 ID.
    ///
    /// developers.facebook.com 에서 앱을 만들면 받는 숫자다.
    /// 받으면 `Info.plist` 에 `FacebookAppID` 한 줄만 넣으면 된다 — 코드는 손댈 것이 없다.
    static var appID: String? {
        let value = Bundle.main.object(forInfoDictionaryKey: "FacebookAppID") as? String
        return (value?.isEmpty == false) ? value : nil
    }

    /// 배경 그림 한 장을 얹고 인스타그램을 연다.
    ///
    /// 스토리는 한 장짜리라 여러 장을 한꺼번에 보내지 않는다.
    /// 보고 있는 카드 하나만 건네고, 나머지는 공유 시트 쪽이 맡는다.
    /// - Returns: 보냈는지. 인스타그램이 없으면 `false` 이고 **붙임판도 건드리지 않는다.**
    @discardableResult
    static func open(backgroundImage data: Data) -> Bool {
        guard isAvailable, let url else { return false }

        // 붙임판은 **5분 뒤에 저절로 비워지게** 둔다.
        // 남겨 두면 한참 뒤에 남의 앱에서 붙여넣기를 눌렀을 때 우리 카드가 튀어나온다.
        UIPasteboard.general.setItems(
            [[Key.backgroundImage: data]],
            options: [.expirationDate: Date().addingTimeInterval(pasteboardLife)]
        )
        UIApplication.shared.open(url)
        return true
    }

    /// 열 주소. `instagram-stories://share?source_application=<앱 ID>`.
    ///
    /// 앱 ID 는 `isAvailable` 이 이미 확인했다. 여기까지 왔는데 없으면 보내지 않는다.
    private static var url: URL? {
        guard let appID,
              var components = URLComponents(url: share, resolvingAgainstBaseURL: false)
        else { return nil }

        components.queryItems = [URLQueryItem(name: "source_application", value: appID)]
        return components.url
    }

    /// 붙임판이 살아 있는 시간.
    private static let pasteboardLife: TimeInterval = 5 * 60

    /// 메타가 정한 붙임판 이름표. 글자 하나만 달라도 인스타그램이 못 알아본다.
    private enum Key {
        static let backgroundImage = "com.instagram.sharedSticker.backgroundImage"
    }
}
