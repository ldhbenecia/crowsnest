import AppKit

/// 메뉴바 아이템 이미지 — 전부 템플릿이라 메뉴바 색(다크 · 라이트 · 배경 틴트)을 시스템이 맞춰줌
@MainActor
enum MenuBarImage {
    private static let height: CGFloat = 18
    private static let nameFont = NSFont.systemFont(ofSize: 10, weight: .semibold)
    private static let barHeight: CGFloat = 2.5
    private static let barGap: CGFloat = 2
    private static let approvalSymbol = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))

    /// 폴링마다 라벨이 다시 그려져도 모양이 같으면 이미지를 새로 안 만듦
    private static var lastActive: (pipeline: MenuBarStatus.ActivePipeline, image: NSImage)?

    static func make(for status: MenuBarStatus) -> NSImage {
        switch status {
        case .idle:
            return CrowsnestGlyph.menuBarImage
        case .needsAttention:
            return CrowsnestGlyph.menuBarBadgedImage
        case .active(let pipeline):
            if let lastActive, lastActive.pipeline == pipeline {
                return lastActive.image
            }
            let image = stacked(pipeline)
            lastActive = (pipeline, image)
            return image
        }
    }

    /// 윗줄 이름, 아랫줄 스테이지 막대 — 끝난 칸은 진하게, 도는 칸은 중간, 남은 칸은 옅게
    private static func stacked(_ pipeline: MenuBarStatus.ActivePipeline) -> NSImage {
        let title = pipeline.othersCount > 0 ? "\(pipeline.name) +\(pipeline.othersCount)" : pipeline.name
        let attributes: [NSAttributedString.Key: Any] = [.font: nameFont, .foregroundColor: NSColor.black]
        let hand = pipeline.isAwaitingApproval ? approvalSymbol : nil
        let handWidth = hand.map { $0.size.width + 4 } ?? 0
        let blockWidth = max(44, ceil((title as NSString).size(withAttributes: attributes).width))
        let count = pipeline.progress?.count ?? 1
        let position = pipeline.progress?.position

        let image = NSImage(size: NSSize(width: handWidth + blockWidth, height: height), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            if let hand {
                hand.draw(in: NSRect(x: 0, y: (height - hand.size.height) / 2, width: hand.size.width, height: hand.size.height))
            }
            (title as NSString).draw(at: NSPoint(x: handWidth, y: 0.5), withAttributes: attributes)

            let segmentWidth = (blockWidth - barGap * CGFloat(count - 1)) / CGFloat(count)
            for index in 0..<count {
                let segment = CGRect(
                    x: handWidth + CGFloat(index) * (segmentWidth + barGap),
                    y: height - barHeight - 1,
                    width: segmentWidth,
                    height: barHeight
                )
                let stage = index + 1
                if let position, stage == position, pipeline.isAwaitingApproval {
                    // 승인 대기 칸은 속을 비워서 멈춰 있는 걸 보여줌
                    context.setStrokeColor(NSColor.black.cgColor)
                    context.setLineWidth(1)
                    context.addPath(CGPath(roundedRect: segment.insetBy(dx: 0.5, dy: 0.5), cornerWidth: 1, cornerHeight: 1, transform: nil))
                    context.strokePath()
                    continue
                }
                let alpha: CGFloat = switch position {
                case let position? where stage < position: 1
                case let position? where stage == position: 0.6
                default: 0.22
                }
                context.setFillColor(NSColor.black.withAlphaComponent(alpha).cgColor)
                context.addPath(CGPath(roundedRect: segment, cornerWidth: barHeight / 2, cornerHeight: barHeight / 2, transform: nil))
                context.fillPath()
            }
            return true
        }
        image.isTemplate = true
        let stageDescription = pipeline.isAwaitingApproval ? "승인 대기" : position.map { "\($0)/\(count) 단계 진행 중" } ?? "진행 중"
        image.accessibilityDescription = "\(title) · \(stageDescription)"
        return image
    }
}
