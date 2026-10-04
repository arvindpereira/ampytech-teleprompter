// Renders the 1024x1024 App Store icon: a dark screen with lines of "script" and a red reading-line marker.
// Usage: swift scripts/make_icon.swift <output.png>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let space = CGColorSpace(name: CGColorSpace.sRGB)!
// App Store icons must not have an alpha channel.
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let s = CGFloat(size)

// Background gradient.
let gradient = CGGradient(colorsSpace: space, colors: [
    CGColor(srgbRed: 0.10, green: 0.11, blue: 0.16, alpha: 1),
    CGColor(srgbRed: 0.02, green: 0.02, blue: 0.04, alpha: 1),
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

func bar(y: CGFloat, width: CGFloat, alpha: CGFloat) {
    let height: CGFloat = 64
    let rect = CGRect(x: (s - width) / 2, y: y, width: width, height: height)
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha))
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: height / 2, cornerHeight: height / 2, transform: nil))
    ctx.fillPath()
}

// Lines of text fading out as they scroll up past the reading line (CG origin is bottom-left).
bar(y: 760, width: 520, alpha: 0.22)
bar(y: 640, width: 640, alpha: 0.4)
bar(y: 480, width: 680, alpha: 1.0)
bar(y: 360, width: 560, alpha: 0.85)
bar(y: 240, width: 620, alpha: 0.7)

// Red reading-line arrows either side of the highlighted line.
ctx.setFillColor(CGColor(srgbRed: 1, green: 0.23, blue: 0.19, alpha: 1))
let mid: CGFloat = 512
for (tip, back) in [(CGFloat(150), CGFloat(80)), (s - 150, s - 80)] {
    ctx.move(to: CGPoint(x: back, y: mid + 50))
    ctx.addLine(to: CGPoint(x: tip, y: mid))
    ctx.addLine(to: CGPoint(x: back, y: mid - 50))
    ctx.closePath()
    ctx.fillPath()
}

let url = URL(fileURLWithPath: output)
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("Failed to write \(output)") }
print("Wrote \(output)")
