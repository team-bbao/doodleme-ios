//
//  LocalDataStore.swift
//  DoodleMe
//

import SwiftData

/// 앱 전역 SwiftData 스택. 스키마 정의와 `ModelContainer` 생성을 한곳에서 관리한다.
enum LocalDataStore {

    /// 저장 대상 모델 목록. 새 `@Model`을 추가하면 여기에 함께 등록한다.
    static let schema = Schema([Post.self])

    /// 실제 앱에서 쓰는 디스크 기반 컨테이너.
    static func makeContainer() -> ModelContainer {
        makeContainer(inMemory: false)
    }

    /// 프리뷰·테스트용 인메모리 컨테이너.
    static func makePreviewContainer() -> ModelContainer {
        makeContainer(inMemory: true)
    }

    private static func makeContainer(inMemory: Bool) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }
    }
}
