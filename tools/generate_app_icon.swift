import AppKit
import Foundation

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "tfx/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let sizes = [16, 32, 64, 128, 256, 512, 1024]

for size in sizes {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    drawIcon(size: CGFloat(size))
    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Failed to render icon at \(size)x\(size)")
    }

    let url = outputDirectory.appendingPathComponent("app-icon-\(size).png")
    try data.write(to: url)
}

private func drawIcon(size: CGFloat) {
    let scale = size / 1024
    func r(_ value: CGFloat) -> CGFloat { value * scale }

    NSGraphicsContext.current?.imageInterpolation = .high
    NSGraphicsContext.current?.cgContext.setShouldAntialias(true)

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    let background = NSBezierPath(roundedRect: canvas.insetBy(dx: r(44), dy: r(44)), xRadius: r(210), yRadius: r(210))
    NSColor(calibratedRed: 0.04, green: 0.05, blue: 0.055, alpha: 1).setFill()
    background.fill()

    let terminalRect = NSRect(x: r(132), y: r(190), width: r(760), height: r(620))
    drawShadowedRoundedRect(
        terminalRect,
        radius: r(74),
        fill: NSColor(calibratedRed: 0.015, green: 0.018, blue: 0.018, alpha: 1),
        stroke: NSColor(calibratedRed: 0.19, green: 0.88, blue: 0.42, alpha: 0.72),
        lineWidth: r(18)
    )

    let titleBar = NSBezierPath(
        roundedRect: NSRect(x: terminalRect.minX, y: terminalRect.maxY - r(138), width: terminalRect.width, height: r(138)),
        xRadius: r(74),
        yRadius: r(74)
    )
    NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.08, alpha: 1).setFill()
    titleBar.fill()

    for (index, color) in [
        NSColor(calibratedRed: 1.0, green: 0.32, blue: 0.30, alpha: 1),
        NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.24, alpha: 1),
        NSColor(calibratedRed: 0.25, green: 0.86, blue: 0.36, alpha: 1)
    ].enumerated() {
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: r(208 + 68 * CGFloat(index)), y: terminalRect.maxY - r(88), width: r(34), height: r(34))).fill()
    }

    drawLine(from: CGPoint(x: r(225), y: r(560)), to: CGPoint(x: r(315), y: r(515)), color: .green, width: r(24))
    drawLine(from: CGPoint(x: r(225), y: r(470)), to: CGPoint(x: r(315), y: r(515)), color: .green, width: r(24))
    drawLine(from: CGPoint(x: r(360), y: r(470)), to: CGPoint(x: r(500), y: r(470)), color: .green, width: r(22))

    drawTerminalTextLine(x: r(225), y: r(385), width: r(315), scale: scale)
    drawTerminalTextLine(x: r(225), y: r(330), width: r(245), scale: scale)

    let folderBack = NSBezierPath()
    folderBack.move(to: CGPoint(x: r(480), y: r(262)))
    folderBack.line(to: CGPoint(x: r(808), y: r(262)))
    folderBack.line(to: CGPoint(x: r(852), y: r(530)))
    folderBack.line(to: CGPoint(x: r(610), y: r(530)))
    folderBack.line(to: CGPoint(x: r(568), y: r(584)))
    folderBack.line(to: CGPoint(x: r(448), y: r(584)))
    folderBack.line(to: CGPoint(x: r(448), y: r(306)))
    folderBack.close()
    NSColor(calibratedRed: 0.02, green: 0.38, blue: 0.23, alpha: 1).setFill()
    folderBack.fill()

    let folderFront = NSBezierPath(roundedRect: NSRect(x: r(430), y: r(210), width: r(462), height: r(300)), xRadius: r(46), yRadius: r(46))
    NSColor(calibratedRed: 0.10, green: 0.78, blue: 0.38, alpha: 1).setFill()
    folderFront.fill()
    NSColor(calibratedRed: 0.50, green: 1.0, blue: 0.64, alpha: 0.72).setStroke()
    folderFront.lineWidth = r(12)
    folderFront.stroke()

    drawLine(from: CGPoint(x: r(500), y: r(380)), to: CGPoint(x: r(790), y: r(380)), color: NSColor(calibratedRed: 0.78, green: 1, blue: 0.78, alpha: 0.92), width: r(18))
    drawLine(from: CGPoint(x: r(500), y: r(322)), to: CGPoint(x: r(720), y: r(322)), color: NSColor(calibratedRed: 0.78, green: 1, blue: 0.78, alpha: 0.78), width: r(18))
}

private func drawShadowedRoundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor, lineWidth: CGFloat) {
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.38)
    shadow.shadowOffset = NSSize(width: 0, height: -18 * rect.width / 760)
    shadow.shadowBlurRadius = 32 * rect.width / 760
    shadow.set()

    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()

    NSShadow().set()
    stroke.setStroke()
    path.lineWidth = lineWidth
    path.stroke()
}

private func drawLine(from start: CGPoint, to end: CGPoint, color: NSColor, width: CGFloat) {
    let path = NSBezierPath()
    path.move(to: start)
    path.line(to: end)
    color.setStroke()
    path.lineWidth = width
    path.lineCapStyle = .round
    path.stroke()
}

private func drawTerminalTextLine(x: CGFloat, y: CGFloat, width: CGFloat, scale: CGFloat) {
    drawLine(
        from: CGPoint(x: x, y: y),
        to: CGPoint(x: x + width, y: y),
        color: NSColor(calibratedRed: 0.32, green: 0.95, blue: 0.52, alpha: 0.65),
        width: 16 * scale
    )
}
