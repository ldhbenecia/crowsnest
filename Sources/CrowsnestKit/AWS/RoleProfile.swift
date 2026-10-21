import Foundation

/// 이미 있는 프로필을 바탕으로 롤만 다른 프로필 — 롤을 여러 개 쓰는 사람이 ~/.aws/config 를 직접 고치지 않게
struct RoleProfile: Sendable, Equatable {
    enum Role: Sendable, Equatable {
        /// 기준 프로필과 같은 SSO 로그인으로 계정 · 롤만 바꿈
        case singleSignOn(accountID: String, roleName: String)
        /// 기준 프로필의 자격 증명으로 role_arn 을 assume 함
        case assumeRole(roleARN: String)
    }

    var name: String
    var baseProfile: String
    var role: Role

    /// 기준 프로필에서 그대로 가져올 값
    struct BaseSettings: Sendable, Equatable {
        var ssoSession: String?
        /// sso-session 블록 없이 프로필에 바로 적는 예전 SSO 설정
        var ssoStartURL: String?
        var ssoRegion: String?
        var region: String?

        var usesSingleSignOn: Bool { ssoSession != nil || ssoStartURL != nil }
    }

    static var duplicateNameMessage: String {
        L("같은 이름의 프로필이 이미 있음", "A profile with this name already exists")
    }

    /// 값이 ~/.aws/config 에 그대로 한 줄로 들어가서 줄바꿈 · 공백이 끼면 파일이 깨짐 — 허용 문자만 받음
    /// - 로 시작하면 aws 가 옵션으로 읽어서 첫 글자는 영문 · 숫자로
    func validationError(existingProfiles: [String]) -> String? {
        if name.wholeMatch(of: /[A-Za-z0-9][A-Za-z0-9._-]*/) == nil {
            return L("프로필 이름은 영문 · 숫자로 시작하고 . _ - 까지만 쓸 수 있음", "Profile names start with a letter or number and can only use letters, numbers, . _ and -")
        }
        if existingProfiles.contains(name) {
            return Self.duplicateNameMessage
        }
        switch role {
        case .singleSignOn(let accountID, let roleName):
            if accountID.wholeMatch(of: /[0-9]{12}/) == nil {
                return L("계정 ID 는 숫자 12자리", "The account ID must be 12 digits")
            }
            if roleName.wholeMatch(of: /[A-Za-z0-9][A-Za-z0-9+=,.@_-]*/) == nil {
                return L("롤 이름이 올바르지 않음", "The role name is not valid")
            }
        case .assumeRole(let roleARN):
            if roleARN.wholeMatch(of: /arn:aws[a-z-]*:iam::[0-9]{12}:role\/[A-Za-z0-9+=,.@_\/-]+/) == nil {
                return L("롤 ARN 은 arn:aws:iam::123456789012:role/이름 형식", "The role ARN must look like arn:aws:iam::123456789012:role/Name")
            }
        }
        return nil
    }

    /// aws configure set 으로 쓸 키와 값 — 순서대로 씀
    func settings(base: BaseSettings) -> [(key: String, value: String)] {
        var settings: [(key: String, value: String)] = []
        switch role {
        case .singleSignOn(let accountID, let roleName):
            if let ssoSession = base.ssoSession {
                settings.append(("sso_session", ssoSession))
            } else {
                if let ssoStartURL = base.ssoStartURL { settings.append(("sso_start_url", ssoStartURL)) }
                if let ssoRegion = base.ssoRegion { settings.append(("sso_region", ssoRegion)) }
            }
            settings += [("sso_account_id", accountID), ("sso_role_name", roleName)]
        case .assumeRole(let roleARN):
            settings += [("role_arn", roleARN), ("source_profile", baseProfile)]
        }
        if let region = base.region {
            settings.append(("region", region))
        }
        return settings
    }
}

extension AWSCommandLine {
    func baseSettings(of profile: String) async -> RoleProfile.BaseSettings {
        async let ssoSession = configValue("sso_session", profile: profile)
        async let ssoStartURL = configValue("sso_start_url", profile: profile)
        async let ssoRegion = configValue("sso_region", profile: profile)
        async let region = configValue("region", profile: profile)
        return await RoleProfile.BaseSettings(ssoSession: ssoSession, ssoStartURL: ssoStartURL, ssoRegion: ssoRegion, region: region)
    }

    /// aws CLI 가 ~/.aws/config 를 직접 고치게 둠 — 파일 형식 · 위치(AWS_CONFIG_FILE)를 앱이 따로 다룰 필요가 없음
    func add(_ profile: RoleProfile, base: RoleProfile.BaseSettings) async throws {
        // configure set 은 있는 프로필이면 조용히 덮어씀 — 앱이 목록을 읽은 뒤 터미널에서 만든 프로필까지 보려고 쓰기 직전에 다시 확인
        let existing = String(decoding: try await run(["configure", "list-profiles"]), as: UTF8.self).nonEmptyLines
        guard !existing.contains(profile.name) else {
            throw AWSError(profile: nil, kind: .other, detail: RoleProfile.duplicateNameMessage)
        }
        for setting in profile.settings(base: base) {
            _ = try await run(["configure", "set", setting.key, setting.value, "--profile", profile.name], profile: profile.name)
        }
    }
}
