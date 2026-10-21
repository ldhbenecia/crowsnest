import Testing
@testable import CrowsnestKit

struct PanelGroupingAndUpdateTests {
    @Test func 프로필은_처음_나온_순서로_묶고_안에서는_고른_순서를_지킨다() {
        let selection = [
            PipelineRef(profile: "staging", region: "us-west-2", name: "web"),
            PipelineRef(profile: "production", region: "us-east-1", name: "api"),
            PipelineRef(profile: "staging", region: "us-west-2", name: "worker"),
            PipelineRef(profile: "production", region: "us-east-1", name: "admin"),
        ]

        let groups = PipelineStore.grouped(selection)

        #expect(groups.map(\.profile) == ["staging", "production"])
        #expect(groups.map { $0.refs.map(\.name) } == [["web", "worker"], ["api", "admin"]])
    }

    @Test(arguments: [
        ("0.2.0", "0.1.1", true),
        ("0.10.0", "0.9.0", true),
        ("1.0", "0.9.9", true),
        ("0.1.1", "0.1.1", false),
        ("0.1.0", "0.1.1", false),
        ("0.1.1.1", "0.1.1", true),
    ])
    func 버전은_숫자_단위로_비교한다(candidate: String, current: String, isNewer: Bool) {
        #expect(UpdateChecker.isVersion(candidate, newerThan: current) == isNewer)
    }
}
