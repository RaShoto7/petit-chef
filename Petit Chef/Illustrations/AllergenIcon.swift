import SwiftUI

/// A consistent set of small botanical / pantry line drawings, rather than unrelated SF symbols.
struct AllergenIcon: View {
    let allergen: String

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 24, y: size.height / 28)
            var p = Path()
            switch allergen {
            case "Gluten":
                p.move(to: CGPoint(x: 12, y: 26)); p.addLine(to: CGPoint(x: 12, y: 4))
                for y in [8.0, 14, 20] {
                    p.move(to: CGPoint(x: 12, y: y))
                    p.addQuadCurve(to: CGPoint(x: 5, y: y - 6), control: CGPoint(x: 4, y: y))
                    p.addQuadCurve(to: CGPoint(x: 12, y: y), control: CGPoint(x: 12, y: y - 7))
                    p.move(to: CGPoint(x: 12, y: y + 2))
                    p.addQuadCurve(to: CGPoint(x: 19, y: y - 4), control: CGPoint(x: 20, y: y + 2))
                    p.addQuadCurve(to: CGPoint(x: 12, y: y + 2), control: CGPoint(x: 12, y: y - 5))
                }
            case "Lait":
                p.move(to: CGPoint(x: 8, y: 2)); p.addLines([CGPoint(x: 16, y: 2), CGPoint(x: 16, y: 7), CGPoint(x: 19, y: 11), CGPoint(x: 19, y: 25), CGPoint(x: 5, y: 25), CGPoint(x: 5, y: 11), CGPoint(x: 8, y: 7)]); p.closeSubpath()
                p.move(to: CGPoint(x: 8, y: 6)); p.addLine(to: CGPoint(x: 16, y: 6))
                p.addRoundedRect(in: CGRect(x: 8, y: 13, width: 8, height: 7), cornerSize: CGSize(width: 2, height: 2))
            case let value where value.contains("Œuf"):
                p.move(to: CGPoint(x: 12, y: 3))
                p.addCurve(to: CGPoint(x: 21, y: 18), control1: CGPoint(x: 16, y: 3), control2: CGPoint(x: 21, y: 12))
                p.addCurve(to: CGPoint(x: 3, y: 18), control1: CGPoint(x: 21, y: 28), control2: CGPoint(x: 3, y: 28))
                p.addCurve(to: CGPoint(x: 12, y: 3), control1: CGPoint(x: 3, y: 12), control2: CGPoint(x: 8, y: 3))
                p.move(to: CGPoint(x: 7, y: 16)); p.addQuadCurve(to: CGPoint(x: 10, y: 9), control: CGPoint(x: 7, y: 11))
            default:
                p.move(to: CGPoint(x: 11, y: 25)); p.addQuadCurve(to: CGPoint(x: 14, y: 3), control: CGPoint(x: 18, y: 13))
                p.move(to: CGPoint(x: 15, y: 15)); p.addQuadCurve(to: CGPoint(x: 5, y: 7), control: CGPoint(x: 5, y: 17)); p.addQuadCurve(to: CGPoint(x: 15, y: 15), control: CGPoint(x: 15, y: 6))
                for (x, y) in [(6.0, 22.0), (18.0, 22.0), (20.0, 5.0)] { p.addEllipse(in: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)) }
            }
            context.fill(p, with: .color(DesignSystem.Colors.sage.opacity(0.35)))
            context.stroke(p, with: .color(DesignSystem.Colors.accent), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
        }.accessibilityHidden(true)
    }
}
