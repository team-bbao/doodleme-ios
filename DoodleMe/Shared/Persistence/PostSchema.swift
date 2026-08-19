//
//  PostSchema.swift
//  DoodleMe
//

import Foundation
import SwiftData

/// 저장소 스키마의 첫 버전.
///
/// 배포된 버전이 아직 없으므로 이 버전이 기준선이다.
/// 다음에 `Post` 의 속성을 바꿀 때는 이 파일에 `PostSchemaV2` 를 만들고
/// `PostMigrationPlan.stages` 에 단계를 추가한다.
/// 그래야 테스터가 이미 저장한 그림이 그대로 넘어온다.
enum PostSchemaV1: VersionedSchema {
    nonisolated static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    nonisolated static var models: [any PersistentModel.Type] { [Post.self] }
}

/// 스키마 버전 사이를 잇는 계획.
///
/// 지금은 버전이 하나뿐이라 단계가 비어 있다.
/// 비어 있어도 계획을 붙여 두는 것이 중요하다.
/// 그래야 다음 버전에서 단계만 추가하면 되고,
/// SwiftData 가 저장소에 스키마 버전을 기록해 둔다.
enum PostMigrationPlan: SchemaMigrationPlan {
    nonisolated static var schemas: [any VersionedSchema.Type] { [PostSchemaV1.self] }
    nonisolated static var stages: [MigrationStage] { [] }
}
