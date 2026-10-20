import Foundation

/// 프로필 하나에서 고를 수 있는 파이프라인 목록
struct ProfileCatalog: Identifiable, Sendable {
    let profile: String
    let region: String
    let pipelines: [String]
    let loadError: String?

    var id: String { profile }
}

struct CodePipelineService: Sendable {
    let cli: AWSCommandLine
    let configuration: AppConfiguration

    /// 실행 요약과 스테이지 상태를 동시에 받아 합침 — get-pipeline-state 한 번에 액션까지 다 옴
    func snapshot(of ref: PipelineRef) async -> PipelineSnapshot {
        let scope = Self.scope(profile: ref.profile, region: ref.region)
        async let executions = decode(
            ListPipelineExecutionsResponse.self,
            scope + ["list-pipeline-executions", "--pipeline-name", ref.name, "--max-items", "1"]
        )
        async let state = decode(GetPipelineStateResponse.self, scope + ["get-pipeline-state", "--name", ref.name])
        do {
            return try await PipelineSnapshot(ref: ref, executions: executions, state: state)
        } catch {
            return .failed(ref, reason: error.localizedDescription)
        }
    }

    /// aws configure 에 등록된 프로필을 전부 훑어서 파이프라인 목록을 받아옴
    func loadCatalogs() async throws -> [ProfileCatalog] {
        let output = try await cli.run(["configure", "list-profiles"])
        let profiles = String(decoding: output, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !configuration.hiddenProfiles.contains($0) }

        return await withTaskGroup(of: (Int, ProfileCatalog).self) { group in
            for (index, profile) in profiles.enumerated() {
                group.addTask { (index, await catalog(of: profile)) }
            }
            var catalogs: [(Int, ProfileCatalog)] = []
            for await entry in group {
                catalogs.append(entry)
            }
            return catalogs.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    private func catalog(of profile: String) async -> ProfileCatalog {
        let region = await region(of: profile)
        do {
            let response = try await decode(ListPipelinesResponse.self, Self.scope(profile: profile, region: region) + ["list-pipelines"])
            return ProfileCatalog(profile: profile, region: region, pipelines: response.pipelines.map(\.name).sorted(), loadError: nil)
        } catch {
            return ProfileCatalog(profile: profile, region: region, pipelines: [], loadError: error.localizedDescription)
        }
    }

    /// region 이 비어 있으면 aws configure get 이 종료 코드 1 로 끝남
    private func region(of profile: String) async -> String {
        if let override = configuration.regionOverrides[profile] {
            return override
        }
        let output = try? await cli.run(["configure", "get", "region", "--profile", profile])
        let region = output.map { String(decoding: $0, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        return region.isEmpty ? configuration.defaultRegion : region
    }

    private func decode<Response: Decodable & Sendable>(_ type: Response.Type, _ arguments: [String]) async throws -> Response {
        let output = try await cli.run(arguments + ["--output", "json"])
        return try JSONDecoder().decode(Response.self, from: output)
    }

    private static func scope(profile: String, region: String) -> [String] {
        ["--profile", profile, "--region", region, "codepipeline"]
    }
}
