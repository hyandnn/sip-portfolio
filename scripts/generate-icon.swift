import AppKit

// Package the approved artwork at macOS icon sizes; the source stays in the project.
let output = CommandLine.arguments[1]
let source = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "packaging/artwork/sipfolio-pixel-maine-coon-v3.png"
guard let image = NSImage(contentsOfFile: source) else { fatalError("Cannot read icon artwork: \(source)") }
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: pixels * 4, bitsPerPixel: 32)!
        bitmap.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.current = context
        context.imageInterpolation = pixels < 128 ? .high : .none
        // Export inside a consistent macOS tile. The generated sprite/source stays untouched;
        // peripheral matte specks cannot extend beyond the application icon's frame.
        let canvas = NSRect(x: 0, y: 0, width: pixels, height: pixels)
        context.cgContext.clear(canvas)
        let tileBounds = canvas.insetBy(dx: CGFloat(pixels) * 0.075, dy: CGFloat(pixels) * 0.075)
        let tile = NSBezierPath(roundedRect: tileBounds, xRadius: CGFloat(pixels) * 0.15, yRadius: CGFloat(pixels) * 0.15)
        NSColor.white.setFill()
        tile.fill()
        tile.addClip()
        image.draw(in: canvas, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output).appendingPathComponent(name))
    }
}
