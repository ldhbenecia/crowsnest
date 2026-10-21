import Foundation

/// Info.plist 에 빌드 스크립트가 넣어둔 값 — swift run 으로 띄우면 비어 있음
struct BuildInfo {
    let version: String?
    let commit: String?
    let buildDate: String?

    static let current: BuildInfo = {
        let info = Bundle.main.infoDictionary ?? [:]
        return BuildInfo(
            version: info["CFBundleShortVersionString"] as? String,
            commit: info["CrowsnestCommit"] as? String,
            buildDate: info["CrowsnestBuildDate"] as? String
        )
    }()

    static let repositoryURL = URL(string: "https://github.com/ldhbenecia/crowsnest")!
    static let releasesURL = repositoryURL.appending(path: "releases")

    /// 0.2.0 (abc1234) — 개발 빌드면 nil
    var versionDescription: String? {
        version.map { version in commit.map { "\(version) (\($0))" } ?? version }
    }

    /// 이슈 양식(.github/ISSUE_TEMPLATE/bug_report.yml)의 버전 · macOS 칸을 미리 채운 새 이슈 주소
    /// 프로필 · 파이프라인 이름은 공개 저장소에 남으면 안 돼서 넣지 않음
    var bugReportURL: URL {
        var components = URLComponents(url: Self.repositoryURL.appending(path: "issues/new"), resolvingAgainstBaseURL: false)!
        let system = ProcessInfo.processInfo.operatingSystemVersion
        components.queryItems = [
            URLQueryItem(name: "template", value: "bug_report.yml"),
            URLQueryItem(name: "version", value: versionDescription ?? "development build"),
            URLQueryItem(name: "macos", value: "\(system.majorVersion).\(system.minorVersion).\(system.patchVersion)"),
        ]
        return components.url!
    }
}
