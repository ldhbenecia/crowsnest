import Foundation

/// CodePipeline 의 실행 · 스테이지 · 액션 상태를 한 타입으로 합침
enum PipelineStatus: Hashable, Sendable {
    case succeeded
    case inProgress
    case failed
    case stopping
    case stopped
    case cancelled
    case superseded
    case abandoned
    case unknown(String)

    init(wireValue: String) {
        switch wireValue {
        case "Succeeded": self = .succeeded
        case "InProgress": self = .inProgress
        case "Failed": self = .failed
        case "Stopping": self = .stopping
        case "Stopped": self = .stopped
        case "Cancelled": self = .cancelled
        case "Superseded": self = .superseded
        case "Abandoned": self = .abandoned
        default: self = .unknown(wireValue)
        }
    }

    var emoji: String {
        switch self {
        case .succeeded: "✅"
        case .inProgress: "🔵"
        case .failed: "🔴"
        case .stopping, .stopped: "⏹"
        case .cancelled, .superseded, .abandoned, .unknown: "⚪"
        }
    }

    var label: String {
        switch self {
        case .succeeded: "성공"
        case .inProgress: "진행 중"
        case .failed: "실패"
        case .stopping: "중지 중"
        case .stopped: "중지됨"
        case .cancelled: "취소됨"
        case .superseded: "다음 실행으로 대체됨"
        case .abandoned: "중단됨"
        case .unknown(let wireValue): wireValue
        }
    }
}

extension PipelineStatus: Decodable {
    init(from decoder: any Decoder) throws {
        self.init(wireValue: try decoder.singleValueContainer().decode(String.self))
    }
}

extension Optional where Wrapped == PipelineStatus {
    /// 한 번도 실행된 적 없는 스테이지 · 액션은 상태가 없음
    var emoji: String { self?.emoji ?? "⚪" }
}
