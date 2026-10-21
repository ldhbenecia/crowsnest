import Testing
@testable import CrowsnestKit

struct RoleProfileTests {
    @Test func SSO_롤은_기준_프로필의_SSO_세션과_리전을_물려받는다() {
        let profile = RoleProfile(name: "team-readonly", baseProfile: "base", role: .singleSignOn(accountID: "111111111111", roleName: "ReadOnly"))
        let base = RoleProfile.BaseSettings(ssoSession: "corp", region: "ap-northeast-2")

        let settings = profile.settings(base: base).map { "\($0.key)=\($0.value)" }

        #expect(settings == ["sso_session=corp", "sso_account_id=111111111111", "sso_role_name=ReadOnly", "region=ap-northeast-2"])
    }

    @Test func SSO_세션_블록이_없는_예전_SSO_설정은_시작_URL을_옮겨_적는다() {
        let profile = RoleProfile(name: "team", baseProfile: "base", role: .singleSignOn(accountID: "111111111111", roleName: "Dev"))
        let base = RoleProfile.BaseSettings(ssoStartURL: "https://example.awsapps.com/start", ssoRegion: "us-east-1")

        let keys = profile.settings(base: base).map(\.key)

        #expect(keys == ["sso_start_url", "sso_region", "sso_account_id", "sso_role_name"])
    }

    @Test func 롤_전환은_기준_프로필을_source_profile로_쓴다() {
        let profile = RoleProfile(name: "deployer", baseProfile: "base", role: .assumeRole(roleARN: "arn:aws:iam::111111111111:role/Deployer"))

        let settings = profile.settings(base: .init()).map { "\($0.key)=\($0.value)" }

        #expect(settings == ["role_arn=arn:aws:iam::111111111111:role/Deployer", "source_profile=base"])
    }

    @Test(arguments: [
        RoleProfile(name: "a b", baseProfile: "base", role: .assumeRole(roleARN: "arn:aws:iam::111111111111:role/X")),
        RoleProfile(name: "-x", baseProfile: "base", role: .assumeRole(roleARN: "arn:aws:iam::111111111111:role/X")),
        RoleProfile(name: "base", baseProfile: "base", role: .assumeRole(roleARN: "arn:aws:iam::111111111111:role/X")),
        RoleProfile(name: "new", baseProfile: "base", role: .assumeRole(roleARN: "arn:aws:iam::1111:role/X")),
        RoleProfile(name: "new", baseProfile: "base", role: .assumeRole(roleARN: "arn:aws:iam::111111111111:role/X\nregion = x")),
        RoleProfile(name: "new", baseProfile: "base", role: .singleSignOn(accountID: "11111111111a", roleName: "Dev")),
        RoleProfile(name: "new", baseProfile: "base", role: .singleSignOn(accountID: "111111111111", roleName: "Dev Ops")),
    ])
    func 설정_파일을_깨뜨릴_값은_받지_않는다(profile: RoleProfile) {
        #expect(profile.validationError(existingProfiles: ["base"]) != nil)
    }

    @Test func 올바른_값은_통과한다() {
        let ssoRole = RoleProfile(name: "team.read-only_1", baseProfile: "base", role: .singleSignOn(accountID: "111111111111", roleName: "AWSReadOnly+Access"))
        let assumedRole = RoleProfile(name: "deployer", baseProfile: "base", role: .assumeRole(roleARN: "arn:aws-cn:iam::111111111111:role/path/Deployer"))

        #expect(ssoRole.validationError(existingProfiles: ["base"]) == nil)
        #expect(assumedRole.validationError(existingProfiles: ["base"]) == nil)
    }
}
