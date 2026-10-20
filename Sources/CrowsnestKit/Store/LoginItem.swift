import Observation
import ServiceManagement

/// 로그인할 때 자동 실행 — 시스템 설정 → 일반 → 로그인 항목에 올라감. 값은 시스템이 들고 있어서 config.json 에 안 씀
@MainActor
@Observable
final class LoginItem {
    private(set) var isEnabled = false
    /// 사용자가 시스템 설정에서 허용해야 켜지는 상태
    private(set) var needsApproval = false
    private(set) var errorMessage: String?

    /// 상태는 화면이 뜰 때 refresh 로 읽음 — 뷰가 다시 만들어질 때마다 시스템에 묻지 않게
    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        needsApproval = status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
