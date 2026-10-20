import Foundation

/// ~/.config/crowsnest/config.json — 바꾸면 앱 재시작해야 반영됨
struct AppConfiguration: Codable, Sendable, Equatable {
    /// aws configure 에 region 이 없는 프로필(SSO 전용 등)에 쓸 리전
    var defaultRegion = "ap-northeast-1"
    var regionOverrides: [String: String] = [:]
    var hiddenProfiles: [String] = []
    /// 비워두면 brew · 기본 설치 경로에서 찾음
    var awsCLIPath: String?
    var pollIntervalSeconds = 30
    /// 진행 중인 실행이 하나라도 있을 때의 갱신 주기
    var activePollIntervalSeconds = 10

    static let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".config/crowsnest/config.json")

    init() {}

    init(from decoder: any Decoder) throws {
        let fallback = AppConfiguration()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultRegion = try container.decodeIfPresent(String.self, forKey: .defaultRegion) ?? fallback.defaultRegion
        regionOverrides = try container.decodeIfPresent([String: String].self, forKey: .regionOverrides) ?? fallback.regionOverrides
        hiddenProfiles = try container.decodeIfPresent([String].self, forKey: .hiddenProfiles) ?? fallback.hiddenProfiles
        awsCLIPath = try container.decodeIfPresent(String.self, forKey: .awsCLIPath)
        pollIntervalSeconds = try container.decodeIfPresent(Int.self, forKey: .pollIntervalSeconds) ?? fallback.pollIntervalSeconds
        activePollIntervalSeconds = try container.decodeIfPresent(Int.self, forKey: .activePollIntervalSeconds) ?? fallback.activePollIntervalSeconds
    }

    /// 파일이 없으면 기본값으로 만들어 둠 — 어떤 키가 있는지 열어보면 바로 보이게
    static func load(from url: URL = fileURL) -> (configuration: AppConfiguration, error: String?) {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            let configuration = AppConfiguration()
            try? configuration.write(to: url)
            return (configuration, nil)
        }
        // 있는데 못 읽는 파일은 덮어쓰지 않음
        do {
            let data = try Data(contentsOf: url)
            return (try JSONDecoder().decode(AppConfiguration.self, from: data), nil)
        } catch {
            return (AppConfiguration(), "config.json 을 못 읽어서 기본값으로 실행 중 · \(error.localizedDescription)")
        }
    }

    private func write(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}

/// 메뉴에서 바꾸는 값 — config.json 과 달리 앱이 직접 씀
enum Preferences {
    private static let selectionKey = "selectedPipelines"
    private static let notificationsMutedKey = "notificationsMuted"

    static var selection: [PipelineRef] {
        get {
            guard let data = UserDefaults.standard.data(forKey: selectionKey) else { return [] }
            return (try? JSONDecoder().decode([PipelineRef].self, from: data)) ?? []
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: selectionKey) }
    }

    static var notificationsMuted: Bool {
        get { UserDefaults.standard.bool(forKey: notificationsMutedKey) }
        set { UserDefaults.standard.set(newValue, forKey: notificationsMutedKey) }
    }
}
