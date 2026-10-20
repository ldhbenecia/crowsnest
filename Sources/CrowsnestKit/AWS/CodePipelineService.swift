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
        async let executions = decode(
            ListPipelineExecutionsResponse.self,
            profile: ref.profile,
            region: ref.region,
            ["list-pipeline-executions", "--pipeline-name", ref.name, "--max-items", "1"]
        )
        async let state = decode(
            GetPipelineStateResponse.self,
            profile: ref.profile,
            region: ref.region,
            ["get-pipeline-state", "--name", ref.name]
        )
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
            .nonEmptyLines
            .filter { !configuration.hiddenProfiles.contains($0) }

        let catalogs = await withTaskGroup(of: ProfileCatalog.self) { group in
            for profile in profiles {
                group.addTask { await catalog(of: profile) }
            }
            return await group.reduce(into: [String: ProfileCatalog]()) { $0[$1.profile] = $1 }
        }
        return profiles.compactMap { catalogs[$0] }
    }

    private func catalog(of profile: String) async -> ProfileCatalog {
        let region = await region(of: profile)
        do {
            let response = try await decode(ListPipelinesResponse.self, profile: profile, region: region, ["list-pipelines"])
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
        return output.flatMap { String(decoding: $0, as: UTF8.self).nonEmptyLines.first } ?? configuration.defaultRegion
    }

    private func decode<Response: Decodable & Sendable>(
        _ type: Response.Type,
        profile: String,
        region: String,
        _ arguments: [String]
    ) async throws -> Response {
        let output = try await cli.run(
            ["--profile", profile, "--region", region, "--output", "json", "codepipeline"] + arguments,
            profile: profile
        )
        return try JSONDecoder().decode(Response.self, from: output)
    }
}
