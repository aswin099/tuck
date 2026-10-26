// Renders Tuck's app icon and menu bar glyph from vector drawing code.
// Usage: swift tools/render-icon.swift App/Assets.xcassets
// Design (DESIGN.md): indigo tile, a card tucked into a pocket, amber pin dot.
import AppKit

let indigo700 = NSColor(srgbRed: 0x2B / 255, green: 0x2D / 255, blue: 0x6E / 255, alpha: 1)
let indigo500 = NSColor(srgbRed: 0x8E / 255, green: 0x94 / 255, blue: 0xF2 / 255, alpha: 1)
let indigo200 = NSColor(srgbRed: 0xC9 / 255, green: 0xCC / 255, blue: 0xFF / 255, alpha: 1)
let amber400 = NSColor(srgbRed: 0xFF / 255, green: 0xB5 / 255, blue: 0x47 / 255, alpha: 1)

/// Pixels per drawing unit for the image being rendered. NSShadow sizes are in pixels and
/// don't follow the drawing scale, so shadows multiply by this to look the same at every size.
var pixelScale: CGFloat = 1

func makeShadow(alpha: CGFloat, offsetY: CGFloat, blur: CGFloat) -> NSShadow {
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(alpha)
    shadow.shadowOffset = NSSize(width: 0, height: offsetY * pixelScale)
    shadow.shadowBlurRadius = blur * pixelScale
    return shadow
}

/// Draws the icon in a 1024×1024 coordinate space (y up), scaled to the context.
func drawIcon() {
    // macOS icon grid: 824×824 tile centered in the 1024 canvas, corner radius ~185.
    let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    makeShadow(alpha: 0.28, offsetY: -10, blur: 24).set()
    indigo700.setFill()
    tilePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()

    // Back card, tilted left.
    drawCard(center: NSPoint(x: 470, y: 560), size: NSSize(width: 360, height: 440), angle: 9, color: indigo200, lines: false)
    // Front card, tilted right, with text lines and the pin dot.
    drawCard(center: NSPoint(x: 560, y: 585), size: NSSize(width: 360, height: 440), angle: -6, color: .white, lines: true)

    // Pocket: covers the lower part of the cards.
    let pocket = NSBezierPath()
    pocket.move(to: NSPoint(x: 232, y: 520))
    pocket.line(to: NSPoint(x: 792, y: 520))
    pocket.line(to: NSPoint(x: 792, y: 330))
    pocket.curve(to: NSPoint(x: 712, y: 250), controlPoint1: NSPoint(x: 792, y: 286), controlPoint2: NSPoint(x: 756, y: 250))
    pocket.line(to: NSPoint(x: 312, y: 250))
    pocket.curve(to: NSPoint(x: 232, y: 330), controlPoint1: NSPoint(x: 268, y: 250), controlPoint2: NSPoint(x: 232, y: 286))
    pocket.close()
    NSGraphicsContext.saveGraphicsState()
    makeShadow(alpha: 0.25, offsetY: 8, blur: 18).set()
    indigo500.setFill()
    pocket.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Stitching along the pocket's top edge: 11 whole dashes, centered on the pocket.
    let stitch = NSBezierPath()
    stitch.move(to: NSPoint(x: 281, y: 488))
    stitch.line(to: NSPoint(x: 743, y: 488))
    stitch.lineWidth = 10
    stitch.lineCapStyle = .round
    stitch.setLineDash([22, 22], count: 2, phase: 0)
    indigo200.withAlphaComponent(0.85).setStroke()
    stitch.stroke()

    NSGraphicsContext.restoreGraphicsState()
}

func drawCard(center: NSPoint, size: NSSize, angle: CGFloat, color: NSColor, lines: Bool) {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: center.x, yBy: center.y)
    transform.rotate(byDegrees: angle)
    transform.concat()
    let rect = NSRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)

    makeShadow(alpha: 0.22, offsetY: -6, blur: 16).set()
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: 36, yRadius: 36).fill()
    NSShadow().set()

    if lines {
        indigo700.withAlphaComponent(0.22).setFill()
        let left = rect.minX + 48
        for (i, width) in [200.0, 250.0, 170.0].enumerated() {
            let y = rect.maxY - 120 - CGFloat(i) * 56
            NSBezierPath(roundedRect: NSRect(x: left, y: y, width: width, height: 22), xRadius: 11, yRadius: 11).fill()
        }
        amber400.setFill()
        NSBezierPath(ovalIn: NSRect(x: rect.maxX - 92, y: rect.maxY - 92, width: 44, height: 44)).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
}

/// Menu bar glyph: a template image (black on clear) that macOS tints for light and dark menu bars.
/// A tilted card with text lines, rising out of a pocket, matching the app icon.
func drawGlyph(alpha: CGFloat = 1) {
    // 18×18 point coordinate space.
    NSColor.black.withAlphaComponent(alpha).setFill()
    NSGraphicsContext.saveGraphicsState()
    let t = NSAffineTransform()
    t.translateX(by: 9.4, yBy: 11.2)
    t.rotate(byDegrees: -9)
    t.concat()
    NSBezierPath(roundedRect: NSRect(x: -4.6, y: -5.0, width: 9.2, height: 10.0), xRadius: 1.6, yRadius: 1.6).fill()
    // Text lines cut out of the card.
    NSGraphicsContext.current?.compositingOperation = .clear
    for (y, width) in [(1.6, 5.4), (-0.6, 4.2)] as [(CGFloat, CGFloat)] {
        NSBezierPath(roundedRect: NSRect(x: -2.9, y: y, width: width, height: 1.1), xRadius: 0.55, yRadius: 0.55).fill()
    }
    NSGraphicsContext.current?.compositingOperation = .sourceOver
    NSGraphicsContext.restoreGraphicsState()
    // Clear a gap above the pocket so the card reads as tucked in.
    NSGraphicsContext.current?.compositingOperation = .clear
    NSRect(x: 0, y: 7.2, width: 18, height: 1.4).fill()
    NSGraphicsContext.current?.compositingOperation = .sourceOver
    NSBezierPath(roundedRect: NSRect(x: 2.0, y: 1.6, width: 14.0, height: 5.6), xRadius: 2.2, yRadius: 2.2).fill()
}

func png(pixels: Int, points: CGFloat, draw: () -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    context.imageInterpolation = .high
    NSGraphicsContext.current = context
    let scale = CGFloat(pixels) / points
    pixelScale = scale
    context.cgContext.scaleBy(x: scale, y: scale)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let catalog = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "App/Assets.xcassets")
let fm = FileManager.default
let appIcon = catalog.appendingPathComponent("AppIcon.appiconset")
try? fm.createDirectory(at: appIcon, withIntermediateDirectories: true)

try #"{"info":{"author":"xcode","version":1}}"#.write(to: catalog.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

var images: [String] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try png(pixels: size * scale, points: 1024, draw: drawIcon).write(to: appIcon.appendingPathComponent(name))
        images.append(#"{"filename":"\#(name)","idiom":"mac","scale":"\#(scale)x","size":"\#(size)x\#(size)"}"#)
    }
}
try #"{"images":[\#(images.joined(separator: ","))],"info":{"author":"xcode","version":1}}"#
    .write(to: appIcon.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

// The paused variant is the same glyph at reduced opacity ("dimmed when paused", DESIGN.md).
for (set, alpha) in [("MenuBarIcon", 1.0), ("MenuBarIconPaused", 0.4)] as [(String, CGFloat)] {
    let glyph = catalog.appendingPathComponent("\(set).imageset")
    try? fm.createDirectory(at: glyph, withIntermediateDirectories: true)
    for scale in [1, 2] {
        let name = "menubar\(scale == 2 ? "@2x" : "").png"
        try png(pixels: 18 * scale, points: 18, draw: { drawGlyph(alpha: alpha) }).write(to: glyph.appendingPathComponent(name))
    }
    try #"{"images":[{"filename":"menubar.png","idiom":"mac","scale":"1x"},{"filename":"menubar@2x.png","idiom":"mac","scale":"2x"}],"info":{"author":"xcode","version":1},"properties":{"template-rendering-intent":"template"}}"#
        .write(to: glyph.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

print("Wrote \(images.count) app icon sizes and the menu bar glyphs to \(catalog.path)")
