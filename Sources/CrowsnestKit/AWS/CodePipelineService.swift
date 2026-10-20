import Foundation

/// 프로필 하나에서 고를 수 있는 파이프라인 목록
struct ProfileCatalog: Identifiable, Sendable {
    let profile: String
    let region: String
    let pipelines: [String]
    let loadError: String?

    var id: String { profile }
}

/// 프로필 · 리전 · 자격 증명은 aws CLI 로 읽고, 파이프라인 조회는 API 를 직접 부름
struct CodePipelineService: Sendable {
    private let cli: AWSCommandLine
    private let configuration: AppConfiguration
    private let credentials: CredentialCache
    private let client: CodePipelineClient

    init(cli: AWSCommandLine, configuration: AppConfiguration) {
        self.cli = cli
        self.configuration = configuration
        credentials = CredentialCache(cli: cli)
        client = CodePipelineClient(credentials: credentials)
    }

    /// 새로고침 버튼 — 방금 aws sso login 했을 수 있어서 자격 증명 실패 기억을 지움
    func forgetCredentialFailures() async {
        await credentials.forgetFailures()
    }

    /// 스테이지 상태만 먼저 받고, 직전과 달라졌을 때만 실행 요약까지 받음 — 쉬는 동안엔 요청이 하나로 줄어듦
    func snapshot(of ref: PipelineRef, previous: PipelineSnapshot?) async -> PipelineSnapshot {
        do {
            let state = try await client.call(
                "GetPipelineState", GetPipelineStateRequest(name: ref.name),
                profile: ref.profile, region: ref.region, as: GetPipelineStateResponse.self
            )
            if let previous, let execution = previous.execution {
                let reused = PipelineSnapshot(ref: ref, execution: execution, state: state)
                if reused.hasSameStageProgress(as: previous) {
                    return reused
                }
            }
            let executions = try await client.call(
                "ListPipelineExecutions", ListPipelineExecutionsRequest(pipelineName: ref.name, maxResults: 1),
                profile: ref.profile, region: ref.region, as: ListPipelineExecutionsResponse.self
            )
            return PipelineSnapshot(ref: ref, executions: executions, state: state)
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
            var names: [String] = []
            var nextToken: String?
            repeat {
                let page = try await client.call(
                    "ListPipelines", ListPipelinesRequest(nextToken: nextToken),
                    profile: profile, region: region, as: ListPipelinesResponse.self
                )
                names += page.pipelines.map(\.name)
                nextToken = page.nextToken
            } while nextToken != nil
            return ProfileCatalog(profile: profile, region: region, pipelines: names.sorted(), loadError: nil)
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
}
