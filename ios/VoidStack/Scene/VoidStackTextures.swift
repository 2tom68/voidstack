import UIKit

enum VoidStackTextures {
    /// Soft radial-gradient dot used for particle sprites (mirrors the web renderer's canvas dot).
    static func softDot() -> UIImage {
        let size = CGSize(width: 64, height: 64)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let colors = [UIColor.white.withAlphaComponent(1).cgColor,
                          UIColor.white.withAlphaComponent(0.7).cgColor,
                          UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.4, 1])!
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            ctx.cgContext.drawRadialGradient(
                gradient, startCenter: center, startRadius: 0,
                endCenter: center, endRadius: size.width / 2, options: []
            )
        }
    }

    /// Procedural neon grid line texture applied to the floor plane's emission map.
    static func floorGrid(cols: Int, rows: Int) -> UIImage {
        let cell = 96
        let size = CGSize(width: cell * cols, height: cell * rows)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor.clear.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            cg.setStrokeColor(VoidStackColor.cyan.withAlphaComponent(0.55).cgColor)
            cg.setLineWidth(2)
            for c in 0...cols {
                let x = CGFloat(c * cell)
                cg.move(to: CGPoint(x: x, y: 0))
                cg.addLine(to: CGPoint(x: x, y: size.height))
            }
            for r in 0...rows {
                let y = CGFloat(r * cell)
                cg.move(to: CGPoint(x: 0, y: y))
                cg.addLine(to: CGPoint(x: size.width, y: y))
            }
            cg.strokePath()
        }
    }
}
