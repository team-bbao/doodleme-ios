//
//  LocalDataStore.swift
//  DoodleMe
//

import Foundation
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
            // 아직 정식 마이그레이션 계획이 없다. 스키마가 바뀌어 기존 저장소를 열 수 없으면
            // 앱이 아예 실행되지 않으므로, 개발 단계에서는 저장소를 비우고 새로 만든다.
            //
            // ⚠️ TestFlight 배포 전에 VersionedSchema + SchemaMigrationPlan 으로 반드시 교체해야 한다.
            //    테스터의 데이터가 조용히 사라지면 안 된다.
            guard !inMemory else {
                fatalError("인메모리 ModelContainer 생성 실패: \(error)")
            }
            resetStore(at: configuration.url)
            do {
                return try ModelContainer(for: schema, configurations: configuration)
            } catch {
                fatalError("저장소를 비운 뒤에도 ModelContainer 생성 실패: \(error)")
            }
        }
    }

    /// SQLite 본체와 WAL/SHM 사이드카까지 함께 지운다.
    private static func resetStore(at url: URL) {
        let fileManager = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let path = URL(fileURLWithPath: url.path + suffix)
            try? fileManager.removeItem(at: path)
        }
    }
}
