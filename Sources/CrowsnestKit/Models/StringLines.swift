import Foundation

extension StringProtocol {
    /// 앞뒤 공백을 걷어낸 비어 있지 않은 줄
    var nonEmptyLines: [String] {
        split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
