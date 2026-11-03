// アイコンを生成する。
//   swift scripts/make-icon.swift <出力ディレクトリ>
// 1024px の PNG と、iconutil に渡す .iconset 一式を吐く。
import AppKit
import Foundation

let outDir = CommandLine.arguments.dropFirst().first ?? "."
let canvas: CGFloat = 1024
let inset: CGFloat = 100
let radius: CGFloat = 185

func makeIcon() -> NSImage {
    let image = NSImage(size: NSSize(width: canvas, height: canvas))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { return image }

    let body = CGRect(x: inset, y: inset,
                      width: canvas - inset * 2, height: canvas - inset * 2)
    let squircle = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

    ctx.saveGState()
    squircle.addClip()

    // 発光感のある青紫。Liquid Glass は重い塗りより明るい層に寄せる。
    NSGradient(colors: [
        NSColor(srgbRed: 0.51, green: 0.55, blue: 0.98, alpha: 1),
        NSColor(srgbRed: 0.29, green: 0.30, blue: 0.72, alpha: 1),
    ])?.draw(in: body, angle: -90)

    // 左上からの柔らかい光。ガラスの厚みを出す。
    NSGradient(colors: [
        NSColor(white: 1, alpha: 0.42),
        NSColor(white: 1, alpha: 0.0),
    ])?.draw(
        fromCenter: CGPoint(x: body.minX + body.width * 0.28,
                            y: body.maxY - body.height * 0.18),
        radius: 0,
        toCenter: CGPoint(x: body.minX + body.width * 0.28,
                          y: body.maxY - body.height * 0.18),
        radius: body.width * 0.78,
        options: []
    )

    // 下端のわずかな沈み込み
    NSGradient(colors: [
        NSColor(srgbRed: 0.12, green: 0.12, blue: 0.34, alpha: 0.38),
        NSColor(white: 0, alpha: 0.0),
    ])?.draw(in: CGRect(x: body.minX, y: body.minY,
                        width: body.width, height: body.height * 0.34), angle: 90)
    ctx.restoreGState()

    // 上縁の内側ハイライト（ガラスのフチ）
    ctx.saveGState()
    squircle.addClip()
    let rim = NSBezierPath(roundedRect: body.insetBy(dx: 8, dy: 8),
                           xRadius: radius - 8, yRadius: radius - 8)
    rim.lineWidth = 10
    NSColor(white: 1, alpha: 0.30).set()
    rim.stroke()
    ctx.restoreGState()

    // グリフは自前の図形で描く。SF Symbols の利用規約はシンボルを App アイコンに
    // 使うことを禁じているため、powersleep を焼き込んではいけない。
    // 形は scripts/make-symbol.swift の moon.slash と同じ（月＋斜線）。
    let unit = body.width * 0.46 / 68          // 68 = シンボル座標系での月の直径
    let center = CGPoint(x: body.midX, y: body.midY)
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        // シンボル座標（月の中心 (42,-35)、y は下向き）→ キャンバス座標（y は上向き）
        CGPoint(x: center.x + (x - 42) * unit, y: center.y - (y + 35) * unit)
    }
    func circle(_ cx: CGFloat, _ cy: CGFloat, _ d: CGFloat) -> CGPath {
        let o = pt(cx, cy)
        let r = d / 2 * unit
        return CGPath(ellipseIn: CGRect(x: o.x - r, y: o.y - r, width: r * 2, height: r * 2), transform: nil)
    }
    let moon = circle(42, -35, 68).subtracting(circle(42 + 21 + 33 - 34, -35 - 17 + 33 - 34, 66))
    let line = CGMutablePath()
    line.move(to: pt(42 - 33, -35 + 33))
    line.addLine(to: pt(42 + 33, -35 - 33))
    let slash: CGFloat = 7 * unit, gap: CGFloat = 4.5 * unit
    let cut = line.copy(strokingWithWidth: slash + gap * 2, lineCap: .round, lineJoin: .round, miterLimit: 10)
    let bar = line.copy(strokingWithWidth: slash, lineCap: .round, lineJoin: .round, miterLimit: 10)
    let glyph = moon.subtracting(cut).union(bar)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 26,
                  color: NSColor(white: 0, alpha: 0.28).cgColor)
    ctx.addPath(glyph)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

func png(_ image: NSImage, size: CGFloat) -> Data? {
    let target = NSImage(size: NSSize(width: size, height: size))
    target.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
    target.unlockFocus()
    guard let tiff = target.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return nil }
    rep.size = NSSize(width: size, height: size)
    return rep.representation(using: .png, properties: [:])
}

let icon = makeIcon()
let fm = FileManager.default
let iconset = "\(outDir)/AppIcon.iconset"
try? fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let variants: [(String, CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, size) in variants {
    guard let data = png(icon, size: size) else { continue }
    try? data.write(to: URL(fileURLWithPath: "\(iconset)/\(name).png"))
}
if let preview = png(icon, size: 1024) {
    try? preview.write(to: URL(fileURLWithPath: "\(outDir)/AppIcon-1024.png"))
}
print("wrote \(iconset)")
