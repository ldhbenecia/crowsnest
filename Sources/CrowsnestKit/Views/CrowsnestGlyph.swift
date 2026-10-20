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

        // 모서리를 둥글리지 않고 두께에 강약을 줘서 각진 쇠 느낌을 냄
        let ring = CGPath(ellipseIn: CGRect(x: 7.4, y: 0.95, width: 3.2, height: 3.2), transform: nil)
            .copy(strokingWithWidth: 1.35, lineCap: .butt, lineJoin: .miter, miterLimit: 4)
        // 가로대 — 양 끝이 넓어짐
        let stock = polygon([
            (4.7, 4.7), (5.6, 5.1), (12.4, 5.1), (13.3, 4.7),
            (13.3, 6.7), (12.4, 6.3), (5.6, 6.3), (4.7, 6.7),
        ])
        // 몸통 — 아래로 갈수록 두꺼워짐
        let shank = polygon([(8.4, 3.9), (9.6, 3.9), (10.0, 15.3), (8.0, 15.3)])

        let glyph = [stock, shank, arms(), fluke(atAngle: .pi - armEndAngle, outward: 1), fluke(atAngle: armEndAngle, outward: -1)]
            .reduce(ring) { $0.union($1) }
        return glyph.copy(using: &transform) ?? glyph
    }

    /// 아래가 두껍고 끝으로 갈수록 가늘어지는 팔 — 원호를 따라 안쪽 · 바깥쪽 가장자리를 찍어서 이음
    private static func arms() -> CGPath {
        let crownThickness: CGFloat = 2.1
        let endThickness: CGFloat = 1.0
        let steps = 32
        var outer: [CGPoint] = []
        var inner: [CGPoint] = []
        for step in 0...steps {
            // 왼쪽 끝(180° - 끝각)에서 아래(90°)를 지나 오른쪽 끝(끝각)까지 — y 가 아래로 커지는 좌표라 90° 가 아래
            let angle = (.pi - armEndAngle) - (.pi - 2 * armEndAngle) * CGFloat(step) / CGFloat(steps)
            let half = (endThickness + (crownThickness - endThickness) * sin(angle)) / 2
            outer.append(CGPoint(x: armCenter.x + (armRadius + half) * cos(angle), y: armCenter.y + (armRadius + half) * sin(angle)))
            inner.append(CGPoint(x: armCenter.x + (armRadius - half) * cos(angle), y: armCenter.y + (armRadius - half) * sin(angle)))
        }
        let path = CGMutablePath()
        path.addLines(between: outer + inner.reversed())
        path.closeSubpath()
        return path
    }

    private static func polygon(_ points: [(CGFloat, CGFloat)]) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points.map { CGPoint(x: $0.0, y: $0.1) })
        path.closeSubpath()
        return path
    }

    /// 팔 끝에서 바깥 · 위로 뻗는 미늘, 뒤쪽이 파여서 갈고리처럼 보임 — outward 는 팔이 이어지는 각도 방향(왼쪽 끝 +1, 오른쪽 끝 -1)
    private static func fluke(atAngle angle: CGFloat, outward: CGFloat) -> CGPath {
        let end = CGPoint(x: armCenter.x + armRadius * cos(angle), y: armCenter.y + armRadius * sin(angle))
        let tangent = CGVector(dx: -sin(angle) * outward, dy: cos(angle) * outward)
        let normal = CGVector(dx: cos(angle), dy: sin(angle))
        func point(along: CGFloat, across: CGFloat) -> CGPoint {
            CGPoint(x: end.x + tangent.dx * along + normal.dx * across, y: end.y + tangent.dy * along + normal.dy * across)
        }
        let path = CGMutablePath()
        path.addLines(between: [
            point(along: 3.0, across: 0.2),
            point(along: -1.1, across: 2.5),
            point(along: -0.3, across: 0.9),
            point(along: -0.8, across: -0.9),
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
