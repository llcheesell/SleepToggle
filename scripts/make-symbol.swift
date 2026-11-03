// Control Center 用のカスタムシンボル（月＋斜線）を SF Symbols のテンプレート SVG で書き出す。
//   swift scripts/make-symbol.swift <出力 .svg>
//
// Control Center のコントロールは SF Symbol かカスタムシンボル（.symbolset）しか描かない。
// 普通の画像アセットを渡すと「?」になる。SF Symbols に moon.slash 系は無いので自作する。
// 月の抜き（斜線の周りの隙間）は CGPath のブール演算で作る。
import CoreGraphics
import Foundation

let out = CommandLine.arguments.dropFirst().first ?? "moon.slash.svg"

/// 1 ウェイト分の形。座標はシンボル座標（原点はベースライン左、y は上が負）。
func glyph(slash: CGFloat, gap: CGFloat) -> CGPath {
    // 月: 外円から右上へずらした円を引く（SF Symbols の powersleep と同じ向き）
    let c = CGPoint(x: 42, y: -35)
    let outer = CGPath(ellipseIn: CGRect(x: c.x - 34, y: c.y - 34, width: 68, height: 68), transform: nil)
    let bite = CGPath(ellipseIn: CGRect(x: c.x - 34 + 21, y: c.y - 34 - 17, width: 66, height: 66), transform: nil)
    let moon = outer.subtracting(bite)

    // 斜線: 左下から右上
    let line = CGMutablePath()
    line.move(to: CGPoint(x: c.x - 33, y: c.y + 33))
    line.addLine(to: CGPoint(x: c.x + 33, y: c.y - 33))
    let cut = line.copy(strokingWithWidth: slash + gap * 2, lineCap: .round, lineJoin: .round, miterLimit: 10)
    let bar = line.copy(strokingWithWidth: slash, lineCap: .round, lineJoin: .round, miterLimit: 10)
    return moon.subtracting(cut).union(bar)
}

func svgPath(_ path: CGPath) -> String {
    var d = ""
    func f(_ v: CGFloat) -> String { String(format: "%.3f", Double(v)) }
    path.applyWithBlock { el in
        let p = el.pointee.points
        switch el.pointee.type {
        case .moveToPoint: d += "M\(f(p[0].x)) \(f(p[0].y))"
        case .addLineToPoint: d += "L\(f(p[0].x)) \(f(p[0].y))"
        case .addQuadCurveToPoint: d += "Q\(f(p[0].x)) \(f(p[0].y)) \(f(p[1].x)) \(f(p[1].y))"
        case .addCurveToPoint: d += "C\(f(p[0].x)) \(f(p[0].y)) \(f(p[1].x)) \(f(p[1].y)) \(f(p[2].x)) \(f(p[2].y))"
        case .closeSubpath: d += "Z"
        @unknown default: break
        }
    }
    return d
}

// テンプレート v3 の固定ガイド位置（S スケール、100pt 基準）
let weights: [(name: String, x: CGFloat, slash: CGFloat, gap: CGFloat)] = [
    ("Ultralight-S", 559, 3.5, 4.0),
    ("Regular-S", 1449, 7.0, 4.5),
    ("Black-S", 2369, 11.0, 5.0),
]
let width: CGFloat = 84
let baseline: CGFloat = 696

var guides = ""
var symbols = ""
for w in weights {
    let left = w.x
    guides += """
      <line id="left-margin-\(w.name)" style="fill:none;stroke:#00AEEF;stroke-width:0.5;opacity:1.0;" x1="\(left)" x2="\(left)" y1="600.785" y2="720.121"/>
      <line id="right-margin-\(w.name)" style="fill:none;stroke:#00AEEF;stroke-width:0.5;opacity:1.0;" x1="\(left + width)" x2="\(left + width)" y1="600.785" y2="720.121"/>

    """
    symbols += """
      <g id="\(w.name)" transform="matrix(1 0 0 1 \(left) \(baseline))">
       <path d="\(svgPath(glyph(slash: w.slash, gap: w.gap)))"/>
      </g>

    """
}

let svg = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<!--Generator: scripts/make-symbol.swift-->
<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="3300" height="2200">
 <!--glyph: "", point size: 100.0, font version: "", template writer version: "138.0.0"-->
 <g id="Notes">
  <rect height="2200" id="artboard" style="fill:white;opacity:1" width="3300" x="0" y="0"/>
  <text id="template-version" style="stroke:none;fill:black;font-family:sans-serif;font-size:13;" transform="matrix(1 0 0 1 3036 1933)">Template v.3.0</text>
 </g>
 <g id="Guides">
  <line id="Baseline-S" style="fill:none;stroke:#27AAE1;stroke-width:0.5;" x1="263" x2="3036" y1="696" y2="696"/>
  <line id="Capline-S" style="fill:none;stroke:#27AAE1;stroke-width:0.5;" x1="263" x2="3036" y1="625.541" y2="625.541"/>
  <line id="Baseline-M" style="fill:none;stroke:#27AAE1;stroke-width:0.5;" x1="263" x2="3036" y1="1126" y2="1126"/>
  <line id="Capline-M" style="fill:none;stroke:#27AAE1;stroke-width:0.5;" x1="263" x2="3036" y1="1055.54" y2="1055.54"/>
  <line id="Baseline-L" style="fill:none;stroke:#27AAE1;stroke-width:0.5;" x1="263" x2="3036" y1="1556" y2="1556"/>
  <line id="Capline-L" style="fill:none;stroke:#27AAE1;stroke-width:0.5;" x1="263" x2="3036" y1="1485.54" y2="1485.54"/>
\(guides) </g>
 <g id="Symbols">
\(symbols) </g>
</svg>
"""
try svg.write(toFile: out, atomically: true, encoding: .utf8)
print("wrote \(out)")
