import Foundation
import os

/// 설정 창에서 고르는 화면 언어
enum AppLanguage: String, Codable, CaseIterable, Sendable {
    /// macOS 언어가 한국어면 한국어, 아니면 영어
    case system
    case korean = "ko"
    case english = "en"
}

/// 한국어 · 영어 두 가지라 .lproj 대신 코드에 나란히 둠 — 재시작 없이 바로 바뀌고 SwiftPM 리소스 번들을 Text 마다 넘기지 않아도 됨
enum Localization {
    /// 알림 · 에러 문구처럼 메인 스레드 밖에서도 읽어서 잠금으로 감쌈
    private static let isKoreanLock = OSAllocatedUnfairLock(initialState: prefersKorean(.system))

    static var isKorean: Bool {
        isKoreanLock.withLock { $0 }
    }

    static func apply(_ language: AppLanguage) {
        isKoreanLock.withLock { $0 = prefersKorean(language) }
    }

    static func prefersKorean(_ language: AppLanguage, preferredLanguages: [String] = Locale.preferredLanguages) -> Bool {
        switch language {
        case .korean: true
        case .english: false
        case .system: preferredLanguages.first?.hasPrefix("ko") ?? false
        }
    }
}

/// 화면에 나가는 문구 — 한국어, 영어 순
func L(_ korean: String, _ english: String) -> String {
    Localization.isKorean ? korean : english
}
