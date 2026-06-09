#!/usr/bin/env swift
import AppKit
import CoreGraphics

let size = 1024
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "/tmp/sam-app-icon-1024.png"

// macOS-Icon-Maske = Superellipse, leicht inset (wie Cursor: Randpixel transparent)
func squirclePath(in rect: CGRect, n: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2
    let b = rect.height / 2
    let cx = rect.midX
    let cy = rect.midY
    let segments = 360
    var first = true
    for i in 0...segments {
        let t = CGFloat(i) / CGFloat(segments) * 2 * .pi
        let cosT = cos(t)
        let sinT = sin(t)
        let x = cx + a * copysign(pow(abs(cosT), 2 / n), cosT)
        let y = cy + b * copysign(pow(abs(sinT), 2 / n), sinT)
        let point = CGPoint(x: x, y: y)
        if first {
            path.move(to: point)
            first = false
        } else {
            path.addLine(to: point)
        }
    }
    path.closeSubpath()
    return path
}

let symbolPointSize = CGFloat(size) * 0.52
let baseConfig = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
let config = baseConfig.applying(NSImage.SymbolConfiguration(paletteColors: [.white]))

guard let symbol = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) else {
    fputs("Failed to load SF Symbol waveform.circle\n", stderr)
    exit(1)
}

let colorSpace = CGColorSpaceCreateDeviceRGB()
let rgbaInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: rgbaInfo
) else {
    fputs("Failed to create context\n", stderr)
    exit(1)
}

let rect = CGRect(x: 0, y: 0, width: size, height: size)

ctx.clear(rect)
ctx.saveGState()
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

ctx.addPath(squirclePath(in: rect))
ctx.clip()

ctx.setFillColor(CGColor(red: 20 / 255, green: 18 / 255, blue: 11 / 255, alpha: 1))
ctx.fill(rect)

let symbolSize = symbol.size
let drawRect = CGRect(
    x: (CGFloat(size) - symbolSize.width) / 2,
    y: (CGFloat(size) - symbolSize.height) / 2,
    width: symbolSize.width,
    height: symbolSize.height
)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
symbol.draw(in: drawRect)
NSGraphicsContext.restoreGraphicsState()
ctx.restoreGState()

guard let finalImage = ctx.makeImage() else {
    fputs("Failed to make image\n", stderr)
    exit(1)
}

let rep = NSBitmapImageRep(cgImage: finalImage)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}

let url = URL(fileURLWithPath: outputPath)
do {
    try png.write(to: url)
    print("Wrote \(outputPath)")
} catch {
    fputs("Write failed: \(error)\n", stderr)
    exit(1)
}

// Optional: Sam.icns direkt erzeugen wenn iconset-Pfad übergeben
if CommandLine.arguments.count > 2 {
    let iconsetDir = CommandLine.arguments[2]
    let icnsPath = CommandLine.arguments[3]
    let fm = FileManager.default
    try? fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)
    let sizes: [(String, Int)] = [
        ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
    ]
    for (name, px) in sizes {
        let dest = (iconsetDir as NSString).appendingPathComponent(name)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        task.arguments = ["-z", "\(px)", "\(px)", outputPath, "--out", dest]
        try? task.run()
        task.waitUntilExit()
    }
    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["-c", "icns", "-o", icnsPath, iconsetDir]
    try? iconutil.run()
    iconutil.waitUntilExit()
    print("Wrote \(icnsPath)")
}
