import Foundation

/// GitHub 에 올라온 더 새 버전
struct AppUpdate: Sendable, Equatable {
    let version: String
    let releaseURL: URL
}

/// 공증 · Homebrew 가 없어서 새 버전이 나와도 알 길이 없음 — GitHub 최신 릴리스 하나만 봄
enum UpdateChecker {
    private static let latestReleaseURL = URL(string: "https://api.github.com/repos\(BuildInfo.repositoryURL.path)/releases/latest")!

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        return URLSession(configuration: configuration)
    }()

    private struct LatestRelease: Decodable {
        let tagName: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
        }
    }

    /// current 보다 새 릴리스가 있을 때만 돌려줌
    static func update(newerThan current: String) async throws -> AppUpdate? {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let release = try JSONDecoder().decode(LatestRelease.self, from: data)
        let version = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
        // 0.2.0 같은 숫자 버전 태그만 — 화면에 그대로 보이고 주소에도 붙음
        guard version.wholeMatch(of: /[0-9]+(\.[0-9]+)*/) != nil, isVersion(version, newerThan: current) else { return nil }
        // 응답에 든 링크 대신 우리 릴리스 주소에 태그만 붙임 — 브라우저로 여는 주소가 늘 github.com 이게
        return AppUpdate(version: version, releaseURL: BuildInfo.releasesURL.appending(path: "tag/\(release.tagName)"))
    }

    /// 0.10.0 이 0.9.0 보다 새 버전 — 그냥 문자열로 비교하면 거꾸로 나옴
    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        candidate.compare(current, options: .numeric) == .orderedDescending
    }
}
