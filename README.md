# doodle.me

서로의 첫인상을 30초동안 그려 공유하는 서비스

## 요구 환경

- Xcode 26+
- iOS 26+
- Swift 6 (strict concurrency)

---

## 기능

- 탭해서 30초 타이머 실행 시키고 첫인상 그리기 (PencilKit)
- 그린 첫인상 카드에 메모 남기기
- 내 첫인상들 모아보기
- 내 첫인상을 프로필로 설정하기
- 가까이 있는 친구와 그림 주고받기 (MultipeerConnectivity)

## 프로젝트 구조

```
DoodleMe/
├── DoodleMeApp.swift                      # @main 진입점
├── RootView.swift                         # 탭 구성
├── Features/
│   ├── Drawing/
│   │   ├── View/
│   │   │   ├── DrawingPage.swift
│   │   │   ├── DrawingCanvas.swift        # PKCanvasView 래퍼
│   │   │   └── DrawingToolPicker.swift
│   │   └── DataModel/
│   │       ├── DrawingSession.swift
│   │       └── DrawingFocusField.swift
│   ├── Gallery/
│   │   ├── View/
│   │   │   ├── GalleryPage.swift
│   │   │   ├── PostGridView.swift
│   │   │   ├── PostDetailView.swift
│   │   │   ├── ProfileNameView.swift
│   │   │   ├── CustomSegmentedControl.swift
│   │   │   └── ConfettiBurst.swift
│   │   └── DataModel/
│   │       └── ConfettiParticle.swift
│   └── Sharing/                           # 가까운 기기끼리 그림 주고받기
│       ├── View/
│       │   └── NearbySharingView.swift
│       └── DataModel/
│           └── MultipeerSession.swift
├── Shared/
│   ├── Model/                             # 공통으로 쓰이는 Model 들 저장
│   │   ├── Post.swift
│   │   ├── PostTransferData.swift
│   │   └── DoodleMetrics.swift
│   ├── View/                              # 피처를 가리지 않고 쓰이는 View
│   │   └── DoodleImageView.swift
│   ├── Extension/                         # Extension 파일들 저장
│   │   ├── PKDrawing+Doodle.swift
│   │   ├── Duration+Seconds.swift
│   │   └── ModelContext+Profile.swift
│   └── Persistence/
│       └── LocalDataStore.swift           # Swift Data 코드 저장
└── Resources/
    ├── Assets.xcassets
    ├── Info.plist
    └── DoodleMeApp.appIcon.icon           # TODO: 아직 없음
```

## 에셋

| 에셋 | 출처 | 조건 |
| --- | --- | --- |
| `RF대충쓴준우체v3` (`DoodleMe/Resources/Fonts/RFjunwooo.ttf`) | RixFont | 출처를 밝히면 상업적 사용 가능 |

> 글꼴 출처를 **사용자가 볼 수 있는 자리**에 적어야 한다.
> 아직 그럴 화면(정보·라이선스)이 없으므로, 배포 전에 앱스토어 설명이나 정보 화면에 넣을 것.

## 문서화

새 기능은 [Swift Evolution](https://github.com/swiftlang/swift-evolution) 형식을 빌려 세 갈래로 문서화한다:

- **`docs/proposals/`** — 왜/무엇을/어떻게 만들었는지에 대한 설계 제안
- **`docs/policies/`** — 그 기능이 지켜야 할 운영 규칙
- **`docs/developments/`** — 실제 구현 과정에서 겪은 이슈·의사결정 기록

## 팀

| Teri | Seung | Jay | Kevin | Erica |
| --- | --- | --- | --- | --- |
| | | Hi, I'm Kevin, the Dongsu | |
