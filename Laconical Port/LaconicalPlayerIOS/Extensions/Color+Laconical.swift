import SwiftUI
import UIKit

extension Color {
    func toHSL() -> (hue: CGFloat, saturation: CGFloat, lightness: CGFloat)? {
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return nil
        }

        let lightness = brightness * (1 - saturation / 2)
        return (hue, saturation, lightness)
    }

    func mixed(with other: Color, amount: CGFloat) -> Color {
        let lhs = UIColor(self)
        let rhs = UIColor(other)

        var lr: CGFloat = 0
        var lg: CGFloat = 0
        var lb: CGFloat = 0
        var la: CGFloat = 0
        var rr: CGFloat = 0
        var rg: CGFloat = 0
        var rb: CGFloat = 0
        var ra: CGFloat = 0

        lhs.getRed(&lr, green: &lg, blue: &lb, alpha: &la)
        rhs.getRed(&rr, green: &rg, blue: &rb, alpha: &ra)

        let t = max(0, min(1, amount))
        return Color(
            red: Double(lr + (rr - lr) * t),
            green: Double(lg + (rg - lg) * t),
            blue: Double(lb + (rb - lb) * t),
            opacity: Double(la + (ra - la) * t)
        )
    }
}
