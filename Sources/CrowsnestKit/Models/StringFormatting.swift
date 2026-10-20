import Foundation

extension StringProtocol {
    /// 앞뒤 공백을 걷어낸 비어 있지 않은 줄
    var nonEmptyLines: [String] {
        split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

extension String {
    /// limit 글자를 넘으면 … 를 넣어 limit 글자로 맞춤 — keepingTail 만큼은 끝에서 남김
    func truncated(to limit: Int, keepingTail tailLength: Int = 0) -> String {
        guard count > limit else { return self }
        return prefix(limit - 1 - tailLength) + "…" + suffix(tailLength)
    }
}
