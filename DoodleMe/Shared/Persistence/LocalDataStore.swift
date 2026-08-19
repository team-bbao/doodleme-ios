//
//  LocalDataStore.swift
//  DoodleMe
//

import Foundation
import OSLog
import SwiftData

/// 앱 전역 SwiftData 스택. 스키마 정의와 `ModelContainer` 생성을 한곳에서 관리한다.
enum LocalDataStore {

    private static let logger = Logger(subsystem: "com.ggdr.doodleme.service", category: "LocalDataStore")

    /// 저장 대상 모델 목록. 새 `@Model` 을 추가하면 최신 버전 스키마에 함께 등록한다.
    static let schema = Schema(versionedSchema: PostSchemaV1.self)

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
            return try ModelContainer(
                for: schema,
                migrationPlan: PostMigrationPlan.self,
                configurations: configuration
            )
        } catch {
            guard !inMemory else {
                fatalError("인메모리 ModelContainer 생성 실패: \(error)")
            }

            // 여기까지 왔다는 건 마이그레이션 계획이 감당하지 못하는 저장소라는 뜻이다.
            //
            // 예전에는 저장소를 **지우고** 새로 만들었다. 개발 중에는 편했지만
            // 배포된 앱에서는 테스터의 그림이 소리 없이 사라진다.
            // 그래서 지우지 않고 이름만 바꿔 옆으로 치운다.
            // 앱은 빈 상태로라도 뜨고, 원본 파일은 그대로 남아 나중에 되살릴 수 있다.
            logger.error("저장소를 열지 못했다. 격리 후 새로 만든다: \(error, privacy: .public)")
            let quarantined = quarantineStore(at: configuration.url)
            logger.error("격리한 저장소: \(quarantined?.lastPathComponent ?? "없음", privacy: .public)")

            do {
                return try ModelContainer(
                    for: schema,
                    migrationPlan: PostMigrationPlan.self,
                    configurations: configuration
                )
            } catch {
                fatalError("저장소를 격리한 뒤에도 ModelContainer 생성 실패: \(error)")
            }
        }
    }

    /// 열리지 않는 저장소를 지우지 않고 옆으로 치운다.
    ///
    /// SQLite 본체와 WAL/SHM 사이드카를 같은 접미사로 함께 옮겨야
    /// 나중에 되살릴 때 세 파일이 짝이 맞는다.
    /// - Returns: 옮겨 둔 본체 경로. 옮기지 못했으면 `nil`.
    @discardableResult
    private static func quarantineStore(at url: URL) -> URL? {
        let fileManager = FileManager.default
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let suffix = ".quarantined-\(stamp)"

        var movedMain: URL?
        for sidecar in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: url.path + sidecar)
            guard fileManager.fileExists(atPath: source.path) else { continue }

            let destination = URL(fileURLWithPath: url.path + suffix + sidecar)
            do {
                try fileManager.moveItem(at: source, to: destination)
                if sidecar.isEmpty { movedMain = destination }
            } catch {
                // 옮기지 못하면 그대로 둔다. 지우는 것보다는 낫다.
                logger.error("격리 실패 \(source.lastPathComponent, privacy: .public): \(error, privacy: .public)")
            }
        }
        return movedMain
    }
}
