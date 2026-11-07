// Renders the background of the Tuck install window (the .dmg), at 1x and 2x.
// Usage: swift tools/dmg/render-background.swift <output folder>
// Writes background.png and background@2x.png. Icon positions live in settings.py;
// keep the arrow between them if either changes.
import AppKit

let size = NSSize(width: 660, height: 400)

let paper = NSColor(srgbRed: 0xF6 / 255, green: 0xF3 / 255, blue: 0xEC / 255, alpha: 1)
let ink = NSColor(srgbRed: 0x1F / 255, green: 0x1F / 255, blue: 0x24 / 255, alpha: 1)
let muted = NSColor(srgbRed: 0x6B / 255, green: 0x6A / 255, blue: 0x72 / 255, alpha: 1)
let rule = NSColor(srgbRed: 0x2B / 255, green: 0x2D / 255, blue: 0x6E / 255, alpha: 0.35)
let indigo700 = NSColor(srgbRed: 0x2B / 255, green: 0x2D / 255, blue: 0x6E / 255, alpha: 1)
let amber400 = NSColor(srgbRed: 0xFF / 255, green: 0xB5 / 255, blue: 0x47 / 255, alpha: 1)

/// Converts a y measured from the top (as Finder and settings.py do) to AppKit's y-up.
func top(_ y: CGFloat) -> CGFloat { size.height - y }

func text(_ string: String, at point: NSPoint, font: NSFont, color: NSColor, kern: CGFloat = 0) {
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .kern: kern]
    let line = NSAttributedString(string: string, attributes: attributes)
    // `point` is the top-left of the text box.
    line.draw(at: NSPoint(x: point.x, y: top(point.y) - line.size().height))
}

func draw() {
    paper.setFill()
    NSRect(origin: .zero, size: size).fill()

    // Header: name, a rule with an amber pin, and what Tuck is.
    text("Tuck", at: NSPoint(x: 44, y: 34), font: .systemFont(ofSize: 34, weight: .bold), color: ink, kern: -0.5)
    rule.setFill()
    NSRect(x: 44, y: top(92), width: 572, height: 1).fill()
    amber400.setFill()
    NSBezierPath(ovalIn: NSRect(x: 40, y: top(92) - 4, width: 9, height: 9)).fill()
    text("Clipboard manager · macOS 14 or later", at: NSPoint(x: 44, y: 106),
         font: .systemFont(ofSize: 13, weight: .regular), color: muted)

    // Arrow from the app (x 170) to Applications (x 490), both centered at y 220.
    let y = top(220)
    indigo700.setFill()
    NSRect(x: 264, y: y - 1.5, width: 116, height: 3).fill()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 398, y: y))
    head.line(to: NSPoint(x: 378, y: y + 10))
    head.line(to: NSPoint(x: 378, y: y - 10))
    head.close()
    head.fill()
    let hint = NSAttributedString(string: "Drag to install", attributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: muted,
    ])
    hint.draw(at: NSPoint(x: 330 - hint.size().width / 2, y: y - 22 - hint.size().height))

    // Footer: the first-open step people get stuck on, since Tuck isn't notarized.
    rule.setFill()
    NSRect(x: 44, y: top(336), width: 572, height: 1).fill()
    text("First open: if macOS blocks Tuck, go to System Settings › Privacy & Security › Open Anyway.",
         at: NSPoint(x: 44, y: 350), font: .systemFont(ofSize: 11, weight: .regular), color: muted)
}

func png(scale: CGFloat) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
try png(scale: 1).write(to: output.appendingPathComponent("background.png"))
try png(scale: 2).write(to: output.appendingPathComponent("background@2x.png"))
print("Wrote background.png and background@2x.png to \(output.path)")
