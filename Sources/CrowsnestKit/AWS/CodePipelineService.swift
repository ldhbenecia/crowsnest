import Foundation

/// 프로필 하나에서 고를 수 있는 파이프라인 목록
struct ProfileCatalog: Identifiable, Sendable {
    let profile: String
    let region: String
    let pipelines: [String]
    let loadError: String?
    /// 설정에서 숨긴 프로필 — 설정 창 목록엔 남기고 파이프라인은 조회하지 않음
    var isHidden = false

    var id: String { profile }
}

/// 프로필 · 리전 · 자격 증명은 aws CLI 로 읽고, 파이프라인 조회는 API 를 직접 부름
/// 설정은 들고 있지 않음 — 리전 · 숨김을 바꿔도 서비스(자격 증명 캐시)를 새로 만들 필요가 없게
struct CodePipelineService: Sendable {
    private let cli: AWSCommandLine
    private let credentials: CredentialCache
    private let client: CodePipelineClient

    init(cli: AWSCommandLine) {
        self.cli = cli
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
            return .failed(ref, error: error)
        }
    }

    /// aws configure 에 등록된 프로필을 전부 훑어서 파이프라인 목록을 받아옴
    func loadCatalogs(using configuration: AppConfiguration) async throws -> [ProfileCatalog] {
        let output = try await cli.run(["configure", "list-profiles"])
        let profiles = String(decoding: output, as: UTF8.self).nonEmptyLines

        let catalogs = await withTaskGroup(of: ProfileCatalog.self) { group in
            for profile in profiles {
                group.addTask { await catalog(of: profile, configuration: configuration) }
            }
            return await group.reduce(into: [String: ProfileCatalog]()) { $0[$1.profile] = $1 }
        }
        return profiles.compactMap { catalogs[$0] }
    }

    private func catalog(of profile: String, configuration: AppConfiguration) async -> ProfileCatalog {
        let region = await region(of: profile, configuration: configuration)
        guard !configuration.hiddenProfiles.contains(profile) else {
            return ProfileCatalog(profile: profile, region: region, pipelines: [], loadError: nil, isHidden: true)
        }
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

    private func region(of profile: String, configuration: AppConfiguration) async -> String {
        if let override = configuration.regionOverrides[profile] {
            return override
        }
        return await cli.configValue("region", profile: profile) ?? configuration.defaultRegion
    }
}
