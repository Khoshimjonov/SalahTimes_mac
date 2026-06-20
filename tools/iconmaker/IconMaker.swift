// Generates a fresh macOS app icon (1024×1024 PNG) for SalahTimes.
//
// Dead simple: full-bleed solid-green square with a white crescent + star.
// No rounded corners, no gradient, no shadows — macOS Tahoe applies its
// own squircle mask and tile, and any extra shape we draw on top of that
// causes double-tile artifacts.
//
// Usage:  swift IconMaker.swift <out_dir>
// Emits:  out_dir/icon_1024.png

import AppKit
import CoreGraphics
import Foundation

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: IconMaker.swift <out_dir>\n".utf8))
    exit(1)
}
let outDir = URL(fileURLWithPath: args[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let side: CGFloat = 1024
let size = CGSize(width: side, height: side)
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let info = CGImageAlphaInfo.premultipliedLast.rawValue

guard let ctx = CGContext(
    data: nil,
    width: Int(size.width),
    height: Int(size.height),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: cs,
    bitmapInfo: info
) else { fatalError("could not create CGContext") }

// Solid green, full bleed.
ctx.setFillColor(CGColor(srgbRed: 0.27, green: 0.74, blue: 0.36, alpha: 1))
ctx.fill(CGRect(origin: .zero, size: size))

// Crescent: outer circle minus an offset inner circle (even-odd fill).
let center = CGPoint(x: side / 2, y: side / 2)
let outerR: CGFloat = side * 0.30
let outerCircle = CGRect(
    x: center.x - outerR - side * 0.04,
    y: center.y - outerR,
    width: outerR * 2,
    height: outerR * 2
)
let innerR = outerR * 0.86
let innerCircle = CGRect(
    x: center.x - innerR + side * 0.06,
    y: center.y - innerR + side * 0.025,
    width: innerR * 2,
    height: innerR * 2
)
let crescent = CGMutablePath()
crescent.addEllipse(in: outerCircle)
crescent.addEllipse(in: innerCircle)
ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
ctx.addPath(crescent)
ctx.fillPath(using: .evenOdd)

// 5-point star inside the crescent's open mouth.
let starCenter = CGPoint(x: center.x + side * 0.16, y: center.y - side * 0.04)
let starOuter: CGFloat = side * 0.115
let starInner: CGFloat = starOuter * 0.42
let star = CGMutablePath()
for i in 0..<10 {
    let r = (i % 2 == 0) ? starOuter : starInner
    let angle = CGFloat(i) * .pi / 5 - .pi / 2
    let p = CGPoint(x: starCenter.x + cos(angle) * r,
                    y: starCenter.y - sin(angle) * r)  // y-up: negate sin
    if i == 0 { star.move(to: p) } else { star.addLine(to: p) }
}
star.closeSubpath()
ctx.addPath(star)
ctx.fillPath()

// Export.
guard let cgImage = ctx.makeImage() else { fatalError("makeImage failed") }
let bitmap = NSBitmapImageRep(cgImage: cgImage)
bitmap.size = NSSize(width: side, height: side)
guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("PNG encode failed")
}
let outURL = outDir.appendingPathComponent("icon_1024.png")
try pngData.write(to: outURL)
print("wrote \(outURL.path)")
