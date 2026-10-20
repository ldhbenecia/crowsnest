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

    var label: String {
        switch self {
        case .succeeded: L("성공", "Succeeded")
        case .inProgress: L("진행 중", "In progress")
        case .failed: L("실패", "Failed")
        case .stopping: L("중지 중", "Stopping")
        case .stopped: L("중지됨", "Stopped")
        case .cancelled: L("취소됨", "Cancelled")
        case .superseded: L("다음 실행으로 대체됨", "Superseded")
        case .abandoned: L("중단됨", "Abandoned")
        case .unknown(let wireValue): wireValue
        }
    }
}

extension PipelineStatus: Decodable {
    init(from decoder: any Decoder) throws {
        self.init(wireValue: try decoder.singleValueContainer().decode(String.self))
    }
}
