import Foundation

/// ~/.config/crowsnest/config.json — 설정 창이 바로 쓰고 바로 반영함. 파일로 관리하고 싶으면 직접 고쳐도 됨(그땐 재시작)
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
    var slowDownInLowPowerMode = true

    var notificationsEnabled = true
    var notifyOnSuccess = true
    var notifyOnFailure = true
    var notifyOnApprovalRequest = true
    var notifyOnRejection = true
    var notificationSound = true

    var language = AppLanguage.system

    static let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".config/crowsnest/config.json")

    init() {}

    /// 없는 키는 기본값 — 예전 버전이 만든 파일도 그대로 읽힘
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func value<Value: Decodable>(_ key: CodingKeys, _ fallback: Value) throws -> Value {
            try container.decodeIfPresent(Value.self, forKey: key) ?? fallback
        }
        let defaults = AppConfiguration()
        defaultRegion = try value(.defaultRegion, defaults.defaultRegion)
        regionOverrides = try value(.regionOverrides, defaults.regionOverrides)
        hiddenProfiles = try value(.hiddenProfiles, defaults.hiddenProfiles)
        awsCLIPath = try container.decodeIfPresent(String.self, forKey: .awsCLIPath)
        pollIntervalSeconds = try value(.pollIntervalSeconds, defaults.pollIntervalSeconds)
        activePollIntervalSeconds = try value(.activePollIntervalSeconds, defaults.activePollIntervalSeconds)
        slowDownInLowPowerMode = try value(.slowDownInLowPowerMode, defaults.slowDownInLowPowerMode)
        notificationsEnabled = try value(.notificationsEnabled, defaults.notificationsEnabled)
        notifyOnSuccess = try value(.notifyOnSuccess, defaults.notifyOnSuccess)
        notifyOnFailure = try value(.notifyOnFailure, defaults.notifyOnFailure)
        notifyOnApprovalRequest = try value(.notifyOnApprovalRequest, defaults.notifyOnApprovalRequest)
        notifyOnRejection = try value(.notifyOnRejection, defaults.notifyOnRejection)
        notificationSound = try value(.notificationSound, defaults.notificationSound)
        // 모르는 값이면 파일 전체를 못 읽는 대신 시스템 언어로
        language = (try? container.decodeIfPresent(AppLanguage.self, forKey: .language)) ?? defaults.language
    }

    func allows(_ kind: DeployNotification.Kind) -> Bool {
        guard notificationsEnabled else { return false }
        return switch kind {
        case .succeeded: notifyOnSuccess
        case .failed, .stopped: notifyOnFailure
        case .awaitingApproval: notifyOnApprovalRequest
        case .rejected: notifyOnRejection
        }
    }

    /// 파일이 없으면 기본값으로 만들어 둠 — 어떤 키가 있는지 열어보면 바로 보이게
    /// error 는 읽기 실패 원인 그대로 — 안내 문구는 화면 언어에 맞춰 store 가 붙임
    static func load(from url: URL = fileURL) -> (configuration: AppConfiguration, error: String?) {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            let configuration = AppConfiguration()
            try? configuration.save(to: url)
            return (configuration, nil)
        }
        // 있는데 못 읽는 파일은 덮어쓰지 않음
        do {
            let data = try Data(contentsOf: url)
            return (try JSONDecoder().decode(AppConfiguration.self, from: data), nil)
        } catch {
            return (AppConfiguration(), error.localizedDescription)
        }
    }

    func save(to url: URL = fileURL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}

/// 앱이 알아서 기억하는 값 — 사람이 고칠 일이 없어서 config.json 대신 UserDefaults
enum Preferences {
    private static let selectionKey = "selectedPipelines"

    static var selection: [PipelineRef] {
        get {
            guard let data = UserDefaults.standard.data(forKey: selectionKey) else { return [] }
            return (try? JSONDecoder().decode([PipelineRef].self, from: data)) ?? []
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: selectionKey) }
    }

    /// 예전 버전은 알림 끄기를 여기 뒀음 — 한 번 읽어서 config.json 으로 옮기고 지움
    static func takeLegacyNotificationsMuted() -> Bool {
        let key = "notificationsMuted"
        guard UserDefaults.standard.object(forKey: key) != nil else { return false }
        defer { UserDefaults.standard.removeObject(forKey: key) }
        return UserDefaults.standard.bool(forKey: key)
    }
}
