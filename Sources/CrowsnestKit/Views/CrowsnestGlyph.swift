import AppKit

/// 배의 닻 — 고리 · 가로대 · 몸통 · 휜 팔 끝의 미늘. 메뉴바 템플릿 아이콘과 앱 아이콘이 같은 모양을 씀
public enum CrowsnestGlyph {
    /// 18 x 18 격자, y 는 아래로 커짐
    public static let gridSize: CGFloat = 18

    /// 팔이 그리는 원호 — 몸통 아래쪽을 감싸고 양 끝이 위로 올라감
    private static let armCenter = CGPoint(x: 9, y: 9.6)
    private static let armRadius: CGFloat = 5.6
    private static let armEndAngle: CGFloat = 25 * .pi / 180

    /// 고리가 왼쪽 위로 가게 기울임 — y 가 아래로 커지는 좌표라 음수가 반시계
    private static let tilt: CGFloat = -30 * .pi / 180

    public static func path(in rect: CGRect) -> CGPath {
        let scale = min(rect.width, rect.height) / gridSize
        let center = gridSize / 2
        var transform = CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: center, y: center)
            .rotated(by: tilt)
            .translatedBy(x: -center, y: -center)

        let ring = CGPath(ellipseIn: CGRect(x: 7.35, y: 0.9, width: 3.3, height: 3.3), transform: nil)
            .copy(strokingWithWidth: 1.15, lineCap: .round, lineJoin: .round, miterLimit: 1)
        let stock = CGPath(roundedRect: CGRect(x: 5.0, y: 5.0, width: 8.0, height: 1.35), cornerWidth: 0.675, cornerHeight: 0.675, transform: nil)
        let shank = CGPath(roundedRect: CGRect(x: 8.3, y: 4.0, width: 1.4, height: 11.6), cornerWidth: 0.7, cornerHeight: 0.7, transform: nil)

        let arms = CGMutablePath()
        // y 가 아래로 커지는 좌표라 각도가 줄어드는 쪽(clockwise)이 아래를 지나감
        arms.addArc(center: armCenter, radius: armRadius, startAngle: .pi - armEndAngle, endAngle: armEndAngle, clockwise: true)
        let strokedArms = arms.copy(strokingWithWidth: 1.4, lineCap: .butt, lineJoin: .round, miterLimit: 1)

        let glyph = [stock, shank, strokedArms, fluke(atAngle: .pi - armEndAngle, outward: 1), fluke(atAngle: armEndAngle, outward: -1)]
            .reduce(ring) { $0.union($1) }
        return glyph.copy(using: &transform) ?? glyph
    }

    /// 팔 끝에서 바깥 · 위로 뻗는 미늘 — outward 는 팔이 이어지는 각도 방향(왼쪽 끝 +1, 오른쪽 끝 -1)
    private static func fluke(atAngle angle: CGFloat, outward: CGFloat) -> CGPath {
        let end = CGPoint(x: armCenter.x + armRadius * cos(angle), y: armCenter.y + armRadius * sin(angle))
        let tangent = CGVector(dx: -sin(angle) * outward, dy: cos(angle) * outward)
        let normal = CGVector(dx: cos(angle), dy: sin(angle))
        func point(along: CGFloat, across: CGFloat) -> CGPoint {
            CGPoint(x: end.x + tangent.dx * along + normal.dx * across, y: end.y + tangent.dy * along + normal.dy * across)
        }
        let path = CGMutablePath()
        path.addLines(between: [
            point(along: 2.7, across: 0.3),
            point(along: -0.7, across: 2.2),
            point(along: -0.7, across: -1.2),
        ])
        path.closeSubpath()
        return path
    }

    @MainActor static let menuBarImage = makeMenuBarImage(badge: false)
    @MainActor static let menuBarBadgedImage = makeMenuBarImage(badge: true)

    /// 템플릿 이미지 — badge 면 닻이 비어 있는 오른쪽 위에 점을 찍고 둘레를 비워서 글리프와 떨어져 보이게 함
    private static func makeMenuBarImage(badge: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: gridSize, height: gridSize), flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.addPath(path(in: rect))
            context.setFillColor(NSColor.black.cgColor)
            context.fillPath()
            guard badge else { return true }
            let center = CGPoint(x: 15.4, y: 2.6)
            context.setBlendMode(.clear)
            context.fillEllipse(in: CGRect(x: center.x - 3.2, y: center.y - 3.2, width: 6.4, height: 6.4))
            context.setBlendMode(.normal)
            context.fillEllipse(in: CGRect(x: center.x - 2.3, y: center.y - 2.3, width: 4.6, height: 4.6))
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = badge ? "Crowsnest · 확인 필요" : "Crowsnest"
        return image
    }
}
