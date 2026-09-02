<img width="304" height="304" alt="스크린샷 2026-09-03 오전 1 23 13" src="https://github.com/user-attachments/assets/4406eab8-e683-4f1c-b506-d3fbc122710d" />


# doodle.me

서로의 첫인상을 30초 동안 그려 주고받는 iOS 앱.

처음 만난 사람의 얼굴을 30초 안에 그리고, 짧은 인사말을 적어 카드로 남깁니다.
가까이 있으면 서버를 거치지 않고 기기끼리 직접 그림을 건넬 수 있습니다.

**목표는 App Store 출시입니다.** 제출에 필요한 문안·설정·체크리스트는
[`docs/app-store-submission.md`](docs/app-store-submission.md) 에 모아 두었습니다.

---

## 요구 환경

| | |
| --- | --- |
| Xcode | 26+ |
| iOS | **26.0+** (그 아래에서는 설치되지 않습니다) |
| Swift | 6.0, strict concurrency |
| 외부 의존성 | **없음** — 전부 Apple 프레임워크 |
| 서버 | **없음** — 모든 데이터가 기기 안에만 있습니다 |

사용 프레임워크: SwiftUI · SwiftData · PencilKit · MultipeerConnectivity · Photos

빌드 설정에서 눈여겨볼 것:

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — **아무 표시가 없으면 MainActor 입니다.**
  시스템이 자기 큐에서 부르는 콜백을 넘길 때는 반드시 `nonisolated` 로 빼야 합니다.
  안 그러면 Swift 6 런타임이 트랩을 걸어 앱이 죽습니다. ([아래 참고](#자주-밟는-지뢰))
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` — `import` 를 파일마다 명시해야 합니다.
- `UIUserInterfaceStyle = Light` — 다크 모드를 쓰지 않습니다. 시스템이 다크여도 밝게 유지됩니다.

---

## 화면

탭바는 왼쪽이 **그리기**, 오른쪽이 **갤러리** 입니다. 앱은 갤러리로 시작합니다.

### 그리기

메모지를 탭하면 커버가 벗겨지고 30초 타이머가 돕니다.
시간이 끝나면 메모 입력 단계로 넘어가고, 받는 사람 이름과 30자 이내 인사말을 적어 저장합니다.

- 손가락과 Apple Pencil 모두 지원 (`drawingPolicy = .anyInput`)
- 연필 / 지우개, 되돌리기 / 다시하기
- **앱이 백그라운드로 내려가면 타이머가 멈추고**, 돌아오면 이어서 갑니다

### 갤러리

받은 그림("너가 그린")과 내가 그린 그림을 세그먼트로 나눠 봅니다.

- 프로필 원을 탭 → 프로필 사진 변경·삭제
- 프로필 이름을 탭 → 이름 수정 (최대 15자)
- **카드를 꾹 누르면** 프로필 사진 설정 / 그림 공유하기 / 삭제
- 우측 상단 버튼 → 그림 공유받기 (보낼 그림 없이 받기 전용)

### 카드 상세

카드를 탭하면 확대되고, 다시 탭하면 뒤집혀 인사말·날짜·상대 이름이 보입니다.
카드 위 버튼으로 가까운 친구에게 보내거나 사진 앱에 저장합니다.

### 가까운 친구에게 보내기

광고(advertise)와 탐색(browse)을 동시에 켜서 서로를 자동으로 찾습니다.
**10초 동안 찾고** 아무도 없으면 안내와 함께 다시 찾기·설정 열기를 띄웁니다.

---

## 프로젝트 구조

기능별로 `Features/` 아래에 모으고, 기능을 가리지 않는 것만 `Shared/` 에 둡니다.
각 기능은 화면(`View/`)과 상태·모델(`DataModel/`)로 나눕니다.

```
DoodleMe/
├── DoodleMeApp.swift                       # @main. ModelContainer 를 여기서 붙인다
├── RootView.swift                          # 탭 구성 (그리기 · 갤러리)
│
├── Features/
│   ├── Drawing/
│   │   ├── View/
│   │   │   ├── DrawingPage.swift           # 커버 → 그리기 → 메모 3단계
│   │   │   ├── DrawingCanvas.swift         # PKCanvasView 래퍼. 크기·모서리를 안에서 못박는다
│   │   │   └── DrawingToolPicker.swift
│   │   └── DataModel/
│   │       ├── DrawingSession.swift        # 단계 · 카운트다운 · 되돌리기 기록
│   │       ├── PKDrawing+Velocity.swift    # 긋는 속도로 굵기를 매긴다 (손가락 필압)
│   │       └── DrawingFocusField.swift
│   │
│   ├── Gallery/
│   │   ├── View/
│   │   │   ├── GalleryPage.swift           # 헤더 · 그리드 · 팝업들을 쌓는 곳
│   │   │   ├── PostGridView.swift          # 카드 그리드. 꾹 누르기 메뉴
│   │   │   ├── PostDetailView.swift        # 확대 · 뒤집기 · 사진 저장
│   │   │   ├── ProfileNameView.swift
│   │   │   ├── CustomSegmentedControl.swift
│   │   │   └── ConfettiBurst.swift
│   │   └── DataModel/
│   │       ├── GalleryMode.swift           # 평소 / 프로필 고르는 중
│   │       └── ConfettiParticle.swift
│   │
│   └── Sharing/
│       ├── View/
│       │   └── NearbySharingScreen.swift   # 찾는중 · 발견 · 못 찾음 화면
│       └── DataModel/
│           ├── MultipeerSession.swift      # 광고 · 탐색 · 전송 · 수신
│           └── PeerAvatarPalette.swift     # 상대에게 붙일 기본 얼굴 5종
│
├── Shared/
│   ├── Model/
│   │   ├── Post.swift                      # @Model. 그림 한 장
│   │   ├── PostTransferData.swift          # 주고받을 때의 표현 + 입력 크기 제한
│   │   ├── DefaultDoodle.swift             # 기본 낙서를 점열로 구워 둔 것
│   │   └── DoodleMetrics.swift             # 캔버스 크기 · 모서리 반경
│   ├── View/
│   │   ├── DoodleImageView.swift           # 저장된 그림을 이미지로 보여준다
│   │   ├── DoodleStrokeAnimation.swift     # 그려진 순서대로 되살리는 연출
│   │   ├── DoodlePopup.swift
│   │   └── PaperBackground.swift           # 종이 질감 배경
│   ├── Extension/
│   │   ├── PKDrawing+Doodle.swift          # 복원 · 이미지로 굽기(모서리 자르기 포함)
│   │   ├── Color+Doodle.swift              # Figma 에서 뽑은 색
│   │   ├── Duration+Seconds.swift
│   │   └── ModelContext+Profile.swift      # 프로필은 하나만 유지하도록 강제
│   └── Persistence/
│       ├── LocalDataStore.swift            # ModelContainer 생성 · 실패 시 격리
│       └── PostSchema.swift                # VersionedSchema + 마이그레이션 계획
│
└── Resources/
    ├── Assets.xcassets                     # 아이콘 · 종이 · 메모지 · 상대 얼굴 5종
    ├── Info.plist
    └── PrivacyInfo.xcprivacy               # 추적 없음 · 수집 없음 · UserDefaults 사유
```

---

## 알아두면 좋은 설계

### 데이터

그림은 `PKDrawing.dataRepresentation()` 바이너리로 `Post` 에 담아 SwiftData 에 저장합니다.
좌표는 모두 `DoodleMetrics.canvasSize`(350×390) 기준이라, 어느 화면에서 줄여 보여줘도 비율이 같습니다.

`PostSchema.swift` 에 `VersionedSchema` 를 두었습니다.
**`Post` 의 속성을 바꿀 때는 반드시 `PostSchemaV2` 를 만들고 마이그레이션 단계를 추가하세요.**
저장소를 열지 못하면 지우지 않고 이름만 바꿔 옆으로 치웁니다. 사용자 그림이 조용히 사라지지 않게 하기 위함입니다.

### 그리기

되돌리기는 PencilKit 것을 쓰지 않고 **그림 스냅숏을 직접 쌓습니다.**
획이 끝날 때마다 속도로 굵기를 다시 매기며 `PKCanvasView.drawing` 을 통째로 갈아끼우는데,
그러면 PencilKit 이 등록해 둔 되돌리기가 헛돌기 때문입니다.

손가락에는 압력 값이 없어 PencilKit 만으로는 굵기가 변하지 않습니다.
그래서 점 사이의 거리와 시각으로 속도를 구해 굵기를 매깁니다. 느리면 두껍고 빠르면 얇습니다.

### 주고받기

`MCSession` 은 `.required` 암호화를 씁니다. 자체 암호화 구현은 없습니다.
`MCPeerID` 는 기기에 저장해 재사용합니다. 열 때마다 새로 만들면 같은 기기가 매번 다른 사람으로 보여,
상대 목록에 남은 예전 항목으로 초대를 보내게 됩니다.

받은 데이터는 신뢰할 수 없는 입력이라 `PostTransferData` 에서 크기·길이 상한을 검사합니다.

### 자주 밟는 지뢰

이 프로젝트는 **기본 액터 격리가 MainActor** 입니다.
시스템이 자기 큐에서 부르는 콜백을 그냥 넘기면 클로저까지 MainActor 로 추론되고,
Swift 6 런타임이 "약속한 액터가 아니다"라며 트랩을 겁니다. 앱이 즉시 죽습니다.

```swift
// ✗ 죽는다 — Photos 가 자기 큐에서 부른다
try await PHPhotoLibrary.shared().performChanges { ... }

// ✓ nonisolated 함수로 빼서 격리를 벗긴다
private nonisolated static func addToPhotoLibrary(_ data: Data) async throws {
    try await PHPhotoLibrary.shared().performChanges { ... }
}
```

`MultipeerSession` 의 델리게이트도 같은 이유로 `nonisolated` 어댑터를 거칩니다.
`CLLocationManager`, `AVFoundation` 같은 콜백 기반 API 를 새로 붙일 때도 같은 처리가 필요합니다.

---

## 빌드와 실행

```bash
open DoodleMe.xcodeproj
```

시뮬레이터에서 주고받기를 확인하려면 **두 대 이상**을 띄우고 양쪽에서 공유 화면을 열어야 합니다.
한 대만으로는 상대를 찾을 수 없어 10초 뒤 "찾지 못했어요" 가 뜹니다.

---

## 출시

제출 문안·설정·체크리스트는 [`docs/app-store-submission.md`](docs/app-store-submission.md) 에 있습니다.
그 문서의 **12번 제출 직전 체크리스트**부터 보면 됩니다.

간단히는 이렇습니다.

1. App Store Connect 에 앱 레코드 생성 (번들 ID `com.ggdr.doodleme.service`)
2. Xcode 에서 기기 선택을 **Any iOS Device** 로 두고 Product → Archive
3. Organizer → Distribute App
4. 서명 단계에서 배포용 인증서 생성을 물어보면 승인

### 아직 막혀 있는 것

- **지원 URL** — App Store 제출 필수 항목인데 아직 없습니다
- **배포용 인증서** — 키체인에 개발용만 있습니다. Xcode 에서 발급해야 합니다

### 아직 확인하지 못한 것

- **실기기 멀티피어** — 잘 안 된다는 보고가 있었고 원인 4건을 고쳤지만 재검증하지 못했습니다
- **로컬 네트워크 권한 거부 경로** — 시뮬레이터는 이 권한을 강제하지 않습니다
- 전송 실패·연결 끊김, 아주 큰 그림 전송

### 정해야 할 것

- 최소 iOS 26.0 을 유지할지 (낮추려면 `glassEffect` 등을 대체해야 합니다)
- 다국어 — 지금은 한국어 전용이고 문자열이 코드에 박혀 있습니다

---

## 문서화

새 기능은 [Swift Evolution](https://github.com/swiftlang/swift-evolution) 형식을 빌려 세 갈래로 문서화합니다.

- **`docs/proposals/`** — 왜/무엇을/어떻게 만들었는지에 대한 설계 제안
- **`docs/policies/`** — 그 기능이 지켜야 할 운영 규칙
- **`docs/developments/`** — 실제 구현 과정에서 겪은 이슈·의사결정 기록
- **`docs/app-store-submission.md`** — 출시에 필요한 모든 것

---

## 에셋

| 에셋 | 출처 | 조건 |
| --- | --- | --- |
| `RF대충쓴준우체v3` (`DoodleMe/Resources/Fonts/RFjunwooo.ttf`) | RixFont | 출처를 밝히면 상업적 사용 가능 |

> 글꼴 출처를 **사용자가 볼 수 있는 자리**에 적어야 한다.
> 아직 그럴 화면(정보·라이선스)이 없으므로, 배포 전에 앱스토어 설명이나 정보 화면에 넣을 것.

## 팀

| Teri | Seung | Jay | Kevin | Erica |
| --- | --- | --- | --- | --- |
| | | Hi, I'm Kevin, the Dongsu | |
