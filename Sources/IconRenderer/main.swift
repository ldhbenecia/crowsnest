import AppKit
import CrowsnestKit

// 앱 아이콘과 dmg 창 배경을 코드로 그림 — script/make_icon.sh 가 iconutil · tiffutil 로 .icns · .tiff 를 만듦
// 아이콘은 메뉴바 템플릿 글리프와 같은 경로를 써서 둘이 늘 같은 모양

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: IconRenderer <output.iconset> <dmg-background-directory>\n".utf8))
    exit(2)
}
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
let backgroundDirectory = URL(fileURLWithPath: CommandLine.arguments[2])
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: backgroundDirectory, withIntermediateDirectories: true)

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

func render(width: Int, height: Int, to url: URL, draw: (CGContext) -> Void) throws {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = graphicsContext
    draw(graphicsContext.cgContext)
    graphicsContext.flushGraphics()
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

for (name, pixels) in sizes {
    try render(width: pixels, height: pixels, to: outputDirectory.appending(path: "\(name).png")) { context in
        drawIcon(in: context, size: CGFloat(pixels))
    }
}

/// dmg 창 660 x 400 — 왼쪽 앱(170, 186) · 오른쪽 Applications(490, 186) 사이에 화살표 하나, 아래에 안내 한 줄
/// 아이콘 위치는 script/dmg_settings.py 와 맞춰야 함
func drawDMGBackground(in context: CGContext, scale: CGFloat) {
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: 0, y: 400)
    context.scaleBy(x: 1, y: -1)

    // 아이콘 바탕과 같은 평평한 검정
    context.setFillColor(CGColor(srgbRed: 22 / 255, green: 22 / 255, blue: 27 / 255, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 660, height: 400))

    // 화살표 — 몸통과 꺾쇠
    let arrowColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.32)
    context.setStrokeColor(arrowColor)
    context.setLineWidth(3)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.move(to: CGPoint(x: 268, y: 186))
    context.addLine(to: CGPoint(x: 390, y: 186))
    context.move(to: CGPoint(x: 376, y: 172))
    context.addLine(to: CGPoint(x: 392, y: 186))
    context.addLine(to: CGPoint(x: 376, y: 200))
    context.strokePath()

    // 안내 — AppKit 글자는 뒤집지 않은 좌표에서 그려야 바로 섬
    let caption = "Drag Crowsnest to Applications to install" as NSString
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .medium),
        .foregroundColor: NSColor(white: 1, alpha: 0.45),
    ]
    let size = caption.size(withAttributes: attributes)
    context.saveGState()
    context.scaleBy(x: 1, y: -1)
    context.translateBy(x: 0, y: -400)
    caption.draw(at: NSPoint(x: (660 - size.width) / 2, y: 400 - 330 - size.height / 2), withAttributes: attributes)
    context.restoreGState()
}

for scale in [1, 2] {
    let name = scale == 1 ? "background.png" : "background@2x.png"
    try render(width: 660 * scale, height: 400 * scale, to: backgroundDirectory.appending(path: name)) { context in
        drawDMGBackground(in: context, scale: CGFloat(scale))
    }
}
