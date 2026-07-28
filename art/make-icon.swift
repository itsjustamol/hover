// Masks the source icon to a macOS squircle with transparent corners and
// writes a 1024x1024 PNG. Run: swift art/make-icon.swift
import AppKit

let sourcePath = "art/icon-source.png"
let outputPath = "art/icon-1024.png"
let size: CGFloat = 1024
// Apple's app-icon corner radius is ~22.37% of the edge length.
let radius: CGFloat = size * 0.2237

guard let source = NSImage(contentsOfFile: sourcePath) else {
    fatalError("cannot read \(sourcePath)")
}

let rep = NSBitmapImageRep(
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
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let rect = NSRect(x: 0, y: 0, width: size, height: size)
NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
NSGraphicsContext.current?.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("png encode failed")
}
try! png.write(to: URL(fileURLWithPath: outputPath))
print("wrote \(outputPath)")
