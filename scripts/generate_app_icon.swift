import AppKit
import Foundation

let resourcesURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Resources", isDirectory: true)
let sourceURL = resourcesURL.appendingPathComponent("AppIconSource.png")
let iconsetURL = resourcesURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fatalError("Missing icon source: \(sourceURL.path)")
}

try FileManager.default.createDirectory(
    at: iconsetURL,
    withIntermediateDirectories: true
)

let icons: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for icon in icons {
    let pngData = renderPNG(size: icon.pixels) { rect in
        drawAppIconSource(in: rect)
    }
    try pngData.write(to: iconsetURL.appendingPathComponent(icon.name), options: .atomic)
}

try writeICNS()
try writeMenuBarTemplateIcon()

func renderPNG(size: CGFloat, draw: (NSRect) -> Void) -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not make bitmap")
    }

    bitmap.size = NSSize(width: size, height: size)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Could not make graphics context")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()
    draw(NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not render PNG")
    }

    return pngData
}

func writeICNS() throws {
    let entries: [(type: String, fileName: String)] = [
        ("icp4", "icon_16x16.png"),
        ("icp5", "icon_32x32.png"),
        ("icp6", "icon_32x32@2x.png"),
        ("ic07", "icon_128x128.png"),
        ("ic08", "icon_256x256.png"),
        ("ic09", "icon_512x512.png"),
        ("ic10", "icon_512x512@2x.png"),
        ("ic11", "icon_16x16@2x.png"),
        ("ic12", "icon_32x32@2x.png"),
        ("ic13", "icon_128x128@2x.png"),
        ("ic14", "icon_256x256@2x.png")
    ]

    var body = Data()
    for entry in entries {
        let pngData = try Data(contentsOf: iconsetURL.appendingPathComponent(entry.fileName))
        body.appendOSType(entry.type)
        body.appendBigEndianUInt32(UInt32(pngData.count + 8))
        body.append(pngData)
    }

    var icns = Data()
    icns.appendOSType("icns")
    icns.appendBigEndianUInt32(UInt32(body.count + 8))
    icns.append(body)
    try icns.write(to: resourcesURL.appendingPathComponent("AppIcon.icns"), options: .atomic)
}

func drawAppIconSource(in rect: NSRect) {
    let clipPath = NSBezierPath(
        roundedRect: rect.insetBy(dx: rect.width * 0.01, dy: rect.height * 0.01),
        xRadius: rect.width * 0.22,
        yRadius: rect.height * 0.22
    )

    NSGraphicsContext.saveGraphicsState()
    clipPath.addClip()
    sourceImage.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
}

func writeMenuBarTemplateIcon() throws {
    let size: CGFloat = 36
    let pngData = renderPNG(size: size) { rect in
        drawMenuBarGlyph(in: rect.insetBy(dx: 5, dy: 5))
    }
    try pngData.write(
        to: resourcesURL.appendingPathComponent("MenuBarIconTemplate.png"),
        options: .atomic
    )
}

func drawMenuBarGlyph(in rect: NSRect) {
    let stroke = max(2.4, rect.width * 0.11)
    let length = rect.width * 0.24
    let cornerInset = rect.width * 0.02
    let minX = rect.minX + cornerInset
    let maxX = rect.maxX - cornerInset
    let minY = rect.minY + cornerInset
    let maxY = rect.maxY - cornerInset

    let corners = NSBezierPath()
    corners.lineCapStyle = .round
    corners.lineJoinStyle = .round
    corners.lineWidth = stroke

    corners.move(to: NSPoint(x: minX, y: maxY - length))
    corners.line(to: NSPoint(x: minX, y: maxY))
    corners.line(to: NSPoint(x: minX + length, y: maxY))

    corners.move(to: NSPoint(x: maxX - length, y: maxY))
    corners.line(to: NSPoint(x: maxX, y: maxY))
    corners.line(to: NSPoint(x: maxX, y: maxY - length))

    corners.move(to: NSPoint(x: minX, y: minY + length))
    corners.line(to: NSPoint(x: minX, y: minY))
    corners.line(to: NSPoint(x: minX + length, y: minY))

    corners.move(to: NSPoint(x: maxX - length, y: minY))
    corners.line(to: NSPoint(x: maxX, y: minY))
    corners.line(to: NSPoint(x: maxX, y: minY + length))

    NSColor.black.setStroke()
    corners.stroke()

    let cursor = NSBezierPath()
    cursor.move(to: NSPoint(x: rect.midX - rect.width * 0.03, y: rect.maxY - rect.height * 0.16))
    cursor.line(to: NSPoint(x: rect.maxX - rect.width * 0.16, y: rect.midY + rect.height * 0.03))
    cursor.curve(
        to: NSPoint(x: rect.midX + rect.width * 0.10, y: rect.midY - rect.height * 0.02),
        controlPoint1: NSPoint(x: rect.maxX - rect.width * 0.04, y: rect.midY - rect.height * 0.02),
        controlPoint2: NSPoint(x: rect.midX + rect.width * 0.18, y: rect.midY - rect.height * 0.08)
    )
    cursor.line(to: NSPoint(x: rect.midX + rect.width * 0.02, y: rect.minY + rect.height * 0.18))
    cursor.curve(
        to: NSPoint(x: rect.midX - rect.width * 0.12, y: rect.minY + rect.height * 0.22),
        controlPoint1: NSPoint(x: rect.midX - rect.width * 0.03, y: rect.minY + rect.height * 0.12),
        controlPoint2: NSPoint(x: rect.midX - rect.width * 0.14, y: rect.minY + rect.height * 0.13)
    )
    cursor.line(to: NSPoint(x: rect.midX - rect.width * 0.03, y: rect.maxY - rect.height * 0.16))
    cursor.close()

    NSColor.black.setFill()
    cursor.fill()
}

extension Data {
    mutating func appendOSType(_ value: String) {
        append(contentsOf: value.utf8)
    }

    mutating func appendBigEndianUInt32(_ value: UInt32) {
        var bigEndianValue = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndianValue) { bytes in
            append(contentsOf: bytes)
        }
    }
}
