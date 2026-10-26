import AppKit

guard CommandLine.arguments.count == 2,
      let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1520, pixelsHigh: 1000,
          bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
          colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Expected output TIFF path and a valid canvas")
}
bitmap.size = NSSize(width: 760, height: 500)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.cgContext.scaleBy(x: 2, y: 2)
NSColor(calibratedRed: 0.953, green: 0.961, blue: 0.977, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: 760, height: 500).fill()

let muted = NSColor(calibratedRed: 0.34, green: 0.41, blue: 0.52, alpha: 1)
for (text, size, baseline, color) in [
    ("安装 Finder2right", 30.0, 440.0, NSColor(calibratedRed: 0.15, green: 0.19, blue: 0.25, alpha: 1)),
    ("将左侧 Finder2right 拖入右侧 Applications", 17.0, 404.0, muted),
    ("先完成拖动安装，再打开 App 启用 Finder 扩展", 16.0, 18.0, muted),
] {
    let string = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: size), .foregroundColor: color,
    ])
    string.draw(at: NSPoint(x: (760 - string.size().width) / 2, y: baseline))
}
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 325, y: 319))
arrow.line(to: NSPoint(x: 435, y: 319))
arrow.move(to: NSPoint(x: 418, y: 335))
arrow.line(to: NSPoint(x: 435, y: 319))
arrow.line(to: NSPoint(x: 418, y: 303))
arrow.lineWidth = 3
NSColor(calibratedRed: 0.62, green: 0.45, blue: 0.88, alpha: 1).setStroke()
arrow.stroke()
NSGraphicsContext.restoreGraphicsState()
guard let tiff = bitmap.representation(using: .tiff, properties: [
    .compressionMethod: NSBitmapImageRep.TIFFCompression.lzw.rawValue,
]) else {
    fatalError("Cannot encode background")
}
try tiff.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
