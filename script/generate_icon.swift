import AppKit

let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)

func drawIcon(size: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    NSColor.clear.setFill(); NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()
    let tile = NSBezierPath(roundedRect: NSRect(x: 76, y: 76, width: 872, height: 872), xRadius: 198, yRadius: 198)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.18); shadow.shadowBlurRadius = 28; shadow.shadowOffset = NSSize(width: 0, height: -10); shadow.set()
    NSColor(calibratedWhite: 0.96, alpha: 1).setFill(); tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: NSColor(calibratedRed: 0.42, green: 0.40, blue: 0.90, alpha: 1), ending: NSColor(calibratedRed: 0.22, green: 0.22, blue: 0.58, alpha: 1))!.draw(in: tile, angle: -70)

    // A tiny two-pane window, rather than overlapping letter cards.
    let window = NSBezierPath(roundedRect: NSRect(x: 184, y: 254, width: 656, height: 516), xRadius: 78, yRadius: 78)
    NSGraphicsContext.saveGraphicsState()
    let windowShadow = NSShadow(); windowShadow.shadowColor = NSColor.black.withAlphaComponent(0.24); windowShadow.shadowBlurRadius = 30; windowShadow.shadowOffset = NSSize(width: 0, height: -14); windowShadow.set()
    NSColor(calibratedWhite: 1, alpha: 0.97).setFill(); window.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor(calibratedRed: 0.89, green: 0.89, blue: 0.98, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 530, y: 283, width: 280, height: 458), xRadius: 50, yRadius: 50).fill()
    for (x, y, width) in [(244.0, 631.0, 204.0), (244, 555, 156), (244, 479, 187), (578, 631, 180), (578, 555, 133), (578, 479, 163)] {
        NSColor(calibratedRed: 0.42, green: 0.42, blue: 0.65, alpha: x > 500 ? 0.6 : 0.35).setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: 23), xRadius: 11.5, yRadius: 11.5).fill()
    }
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 405, y: 378)); arrow.line(to: NSPoint(x: 619, y: 378))
    arrow.move(to: NSPoint(x: 576, y: 421)); arrow.line(to: NSPoint(x: 619, y: 378)); arrow.line(to: NSPoint(x: 576, y: 335))
    arrow.lineWidth = 26; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
    NSColor(calibratedRed: 0.40, green: 0.36, blue: 0.84, alpha: 1).setStroke(); arrow.stroke()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
for size in [16, 32, 128, 256, 512] {
    for density in [1, 2] {
        let name = "icon_\(size)x\(size)\(density == 2 ? "@2x" : "").png"
        try drawIcon(size: size * density).write(to: URL(fileURLWithPath: destination).appendingPathComponent(name))
    }
}
