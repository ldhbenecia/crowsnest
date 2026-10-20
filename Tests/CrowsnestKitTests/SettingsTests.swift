import Foundation
import Testing
@testable import CrowsnestKit

struct SettingsTests {
    @Test func 예전_설정_파일은_새_키를_기본값으로_채운다() throws {
        let old = #"{ "defaultRegion": "eu-west-1", "pollIntervalSeconds": 60 }"#

        let configuration = try JSONDecoder().decode(AppConfiguration.self, from: Data(old.utf8))

        #expect(configuration.defaultRegion == "eu-west-1")
        #expect(configuration.pollIntervalSeconds == 60)
        #expect(configuration.activePollIntervalSeconds == 10)
        #expect(configuration.notificationsEnabled)
        #expect(configuration.notifyOnRejection)
    }

    @Test func 저장한_설정을_그대로_다시_읽는다() throws {
        var configuration = AppConfiguration()
        configuration.notifyOnSuccess = false
        configuration.regionOverrides = ["staging": "us-west-2"]
        let url = FileManager.default.temporaryDirectory.appending(path: "crowsnest-\(UUID().uuidString)/config.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        try configuration.save(to: url)

        #expect(AppConfiguration.load(from: url).configuration == configuration)
    }

    @Test func 알림은_종류별_설정을_따르고_전체를_끄면_다_막힌다() {
        var configuration = AppConfiguration()
        configuration.notifyOnSuccess = false

        #expect(!configuration.allows(.succeeded))
        #expect(configuration.allows(.failed))
        #expect(configuration.allows(.stopped))

        configuration.notificationsEnabled = false
        #expect(!configuration.allows(.failed))
    }

    @Test func 리전을_바꾸면_고른_파이프라인도_새_리전을_가리킨다() {
        let selection = [
            PipelineRef(profile: "staging", region: "ap-northeast-1", name: "web-staging"),
            PipelineRef(profile: "staging", region: "ap-northeast-1", name: "removed-pipeline"),
            PipelineRef(profile: "production", region: "us-east-1", name: "web-prod"),
        ]
        let catalogs = [
            ProfileCatalog(profile: "staging", region: "us-west-2", pipelines: ["web-staging"], loadError: nil),
            ProfileCatalog(profile: "production", region: "us-east-1", pipelines: ["web-prod"], loadError: nil),
        ]

        let followed = PipelineStore.selection(selection, followingRegionsOf: catalogs)

        #expect(followed == [
            PipelineRef(profile: "staging", region: "us-west-2", name: "web-staging"),
            // 새 리전에 없는 건 건드리지 않음 — 조회 실패로 보여서 사용자가 알아챔
            PipelineRef(profile: "staging", region: "ap-northeast-1", name: "removed-pipeline"),
            PipelineRef(profile: "production", region: "us-east-1", name: "web-prod"),
        ])
    }

    @Test func 리전_형식만_받는다() {
        #expect(AWSRegion.isValid("ap-northeast-2"))
        #expect(AWSRegion.isValid("us-gov-west-1"))
        #expect(!AWSRegion.isValid("evil.example.com/#"))
        #expect(!AWSRegion.isValid(""))
    }
}
