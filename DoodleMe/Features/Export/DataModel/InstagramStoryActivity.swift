//
//  InstagramStoryActivity.swift
//  DoodleMe
//

import UIKit

/// 공유 시트 **안에 서는** 「인스타그램 스토리」 항목.
///
/// 시트에 저절로 뜨는 인스타그램은 눌러도 「스토리 · 게시물 · 메시지」를 한 번 더 묻는다.
/// 이 카드는 스토리에 올리려고 만든 것이라 그 한 자리로 곧장 보낸다 —
/// 「복사」·「이미지 저장」 옆에 한 칸을 더 내고, 누르면 스토리 편집기가 열린다.
///
/// 시트 밖에 버튼을 따로 세우지 않는다. 내보내는 길은 공유 하나면 되고,
/// 거기서 무엇으로 보낼지 고르는 것이 아이폰에서 익숙한 차례다.
///
/// 인스타그램이 없는 기기에서는 `canPerform` 이 거절해 칸 자체가 뜨지 않는다.
///
/// **`nonisolated` 인 이유가 있다.** 이 프로젝트는 모든 타입이 기본으로 `@MainActor` 인데
/// `UIActivity` 의 요구사항은 격리되지 않은 것들이라 그대로는 덮어쓸 수 없다.
/// 실제로는 UIKit 이 이 메서드들을 **메인에서** 부르므로, 메인이 필요한 자리에서만
/// `MainActor.assumeIsolated` 로 그 사실을 적어 둔다.
nonisolated final class InstagramStoryActivity: UIActivity {

    /// 스토리로 보낼 **9:16 그림.** 시트를 여는 쪽이 미리 구워 건넨다.
    ///
    /// 시트가 넘겨주는 파일을 쓰지 않는 이유가 있다. 그건 화면에서 보던 그대로인
    /// 도안 칸(390x844, 9:19.5)이라 스토리 편집기가 위아래를 잘라낸다.
    /// 스토리에 들어가는 그림만 좌우로 넓혀 9:16 으로 따로 굽는다.
    private let story: Data?

    init(story: Data?) {
        self.story = story
        super.init()
    }

    override class var activityCategory: UIActivity.Category { .action }

    override var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType("com.ggdr.doodleme.instagram-story")
    }

    /// 시트에 적히는 이름.
    ///
    /// 「인스타그램 스토리」 가 아니라 그냥 「인스타그램」 이다 — 두 줄로 접혀 옆 칸보다
    /// 키가 커졌고, 이 앱에서 인스타그램으로 보내는 길은 어차피 스토리 하나뿐이라
    /// 굳이 자리까지 적어 줄 것이 없다.
    override var activityTitle: String? { "인스타그램" }

    /// 갤러리·미리보기에서 쓰는 것과 같은 글리프.
    /// 시트는 이 그림을 실루엣으로만 쓰므로 색은 신경 쓰지 않아도 된다.
    override var activityImage: UIImage? { UIImage(named: "instagram") }

    /// 인스타그램이 있고, 보낼 그림이 있을 때만 칸을 낸다.
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        guard story != nil else { return false }

        #if targetEnvironment(simulator)
        // **시뮬레이터에는 인스타그램을 깔 수 없다.** 그래서 늘 묻는 대로 「있다」고 답한다 —
        // 칸이 어떻게 서는지 여기서 눈으로 보려는 것이다.
        // 눌러도 열리지는 않으므로 실제로 넘어가는지는 실기기에서 봐야 한다.
        return true
        #else
        return MainActor.assumeIsolated { InstagramStory.isAvailable }
        #endif
    }

    override func perform() {
        guard let story else {
            activityDidFinish(false)
            return
        }
        // 보냈는지 그대로 알린다. 시뮬레이터처럼 인스타그램이 없는 자리에서는
        // 실패로 끝나고, 시트는 「했다」고 거짓말하지 않는다.
        let sent = MainActor.assumeIsolated { InstagramStory.open(backgroundImage: story) }
        activityDidFinish(sent)
    }
}
