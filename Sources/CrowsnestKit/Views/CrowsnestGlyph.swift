import AppKit

/// 돛대 위 망루(크로우즈 네스트)와 깃발 — 메뉴바 템플릿 아이콘과 앱 아이콘이 같은 모양을 씀
public enum CrowsnestGlyph {
    /// 18 x 18 격자, y 는 아래로 커짐
    public static let gridSize: CGFloat = 18

    public static func path(in rect: CGRect) -> CGPath {
        let scale = min(rect.width, rect.height) / gridSize
        var transform = CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: scale, y: scale)
        let path = CGMutablePath()

        // 깃발
        path.addLines(between: [CGPoint(x: 9.7, y: 1.0), CGPoint(x: 14.6, y: 2.6), CGPoint(x: 9.7, y: 4.2)])
        path.closeSubpath()
        // 돛대
        path.addRoundedRect(in: CGRect(x: 8.3, y: 1.0, width: 1.4, height: 16.0), cornerWidth: 0.7, cornerHeight: 0.7)
        // 망루 — 아래가 둥근 통
        path.addPath(basket(in: CGRect(x: 5.2, y: 5.6, width: 7.6, height: 4.0)))
        // 활대
        path.addRoundedRect(in: CGRect(x: 2.6, y: 11.6, width: 12.8, height: 1.4), cornerWidth: 0.7, cornerHeight: 0.7)

        return path.copy(using: &transform) ?? path
    }

    private static func basket(in rect: CGRect) -> CGPath {
        let radius: CGFloat = 1.8
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - radius, y: rect.maxY), radius: radius)
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - radius), radius: radius)
        path.closeSubpath()
        return path
    }

    @MainActor static let menuBarImage = makeMenuBarImage(badge: false)
    @MainActor static let menuBarBadgedImage = makeMenuBarImage(badge: true)

    /// 템플릿 이미지 — badge 면 오른쪽 아래에 점을 찍고 둘레를 비워서 글리프와 떨어져 보이게 함
    private static func makeMenuBarImage(badge: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: gridSize, height: gridSize), flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.addPath(path(in: rect))
            context.setFillColor(NSColor.black.cgColor)
            context.fillPath()
            guard badge else { return true }
            let center = CGPoint(x: 14.6, y: 14.4)
            context.setBlendMode(.clear)
            context.fillEllipse(in: CGRect(x: center.x - 3.9, y: center.y - 3.9, width: 7.8, height: 7.8))
            context.setBlendMode(.normal)
            context.fillEllipse(in: CGRect(x: center.x - 2.7, y: center.y - 2.7, width: 5.4, height: 5.4))
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = badge ? "Crowsnest · 확인 필요" : "Crowsnest"
        return image
    }
}
