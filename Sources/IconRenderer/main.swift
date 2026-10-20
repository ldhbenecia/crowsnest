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

    // 그림자
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 12), blur: 28, color: color(0, 0, 0, 0.45))
    context.addPath(tilePath)
    context.setFillColor(color(10, 10, 16))
    context.fillPath()
    context.restoreGState()

    // 바탕 — 위는 거의 검정, 아래로 갈수록 아주 옅게 남색
    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    let background = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(14, 14, 22), color(8, 8, 12), color(20, 18, 46)] as CFArray,
        locations: [0, 0.55, 1]
    )!
    context.drawLinearGradient(background, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])

    // 망루 뒤로 번지는 인디고 빛
    let glow = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(99, 102, 241, 0.42), color(99, 102, 241, 0)] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 470), startRadius: 0, endCenter: CGPoint(x: 512, y: 470), endRadius: 420, options: [])
    context.restoreGState()

    // 테두리 — 어두운 Dock 위에서도 모서리가 보이게
    context.saveGState()
    context.addPath(CGPath(roundedRect: tile.insetBy(dx: 1.5, dy: 1.5), cornerWidth: 184, cornerHeight: 184, transform: nil))
    context.setStrokeColor(color(255, 255, 255, 0.09))
    context.setLineWidth(3)
    context.strokePath()
    context.restoreGState()

    // 글리프 — 위는 밝은 인디고, 아래는 진한 인디고
    let glyphRect = CGRect(x: 512 - 290, y: 512 - 290, width: 580, height: 580)
    context.saveGState()
    context.addPath(CrowsnestGlyph.path(in: glyphRect))
    context.clip()
    let glyphFill = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(199, 210, 254), color(129, 140, 248), color(79, 70, 229)] as CFArray,
        locations: [0, 0.45, 1]
    )!
    context.drawLinearGradient(glyphFill, start: CGPoint(x: 512, y: glyphRect.minY), end: CGPoint(x: 512, y: glyphRect.maxY), options: [])
    context.restoreGState()
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
