import AppKit
import CrowsnestKit

// 앱 아이콘을 코드로 그려서 .iconset 으로 내보냄 — script/make_icon.sh 가 iconutil 로 .icns 를 만듦
// 메뉴바 템플릿 글리프와 같은 경로를 써서 둘이 늘 같은 모양

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: IconRenderer <output.iconset>\n".utf8))
    exit(2)
}
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

/// 1024 캔버스 기준 — macOS 아이콘 격자의 824 둥근 사각형과 아래로 떨어지는 그림자
func drawIcon(in context: CGContext, size: CGFloat) {
    let scale = size / 1024
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: 0, y: 1024)
    context.scaleBy(x: 1, y: -1)

    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    let colorSpace = CGColorSpace(name: CGColorSpace.displayP3)!

    func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(colorSpace: colorSpace, components: [red / 255, green / 255, blue / 255, alpha])!
    }

    // 바탕 — 빛 번짐 · 그라데이션 없이 평평한 검정, 그림자는 macOS 아이콘 격자 기본만
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 12), blur: 28, color: color(0, 0, 0, 0.45))
    context.addPath(tilePath)
    context.setFillColor(color(14, 14, 18))
    context.fillPath()
    context.restoreGState()

    // 테두리 — 어두운 Dock 위에서도 모서리가 보이게
    context.saveGState()
    context.addPath(CGPath(roundedRect: tile.insetBy(dx: 1.5, dy: 1.5), cornerWidth: 184, cornerHeight: 184, transform: nil))
    context.setStrokeColor(color(255, 255, 255, 0.09))
    context.setLineWidth(3)
    context.strokePath()
    context.restoreGState()

    // 글리프 — 단색 인디고
    let glyphRect = CGRect(x: 512 - 290, y: 512 - 290, width: 580, height: 580)
    context.addPath(CrowsnestGlyph.path(in: glyphRect))
    context.setFillColor(color(129, 140, 248))
    context.fillPath()
}

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for (name, pixels) in sizes {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)!
    drawIcon(in: graphicsContext.cgContext, size: CGFloat(pixels))
    graphicsContext.flushGraphics()
    try bitmap.representation(using: .png, properties: [:])!.write(to: outputDirectory.appending(path: "\(name).png"))
}
