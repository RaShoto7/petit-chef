import SwiftUI

/// Lightweight, resolution-independent illustrations drawn in the app.
/// The quiet ink lines and small irregularities are intentional: a cook's sketchbook.
struct FoodIllustration: View {
    let recipeID: String

    var body: some View {
        Canvas { context, size in
            var sketch = KitchenSketch(context: context, size: size)
            sketch.meal(recipeID: recipeID)
        }
        .accessibilityHidden(true)
    }
}

/// Gesture loops use elapsed time instead of accumulating animation state.
/// A static drawing is used when Reduce Motion is enabled or the app is inactive.
struct AnimatedCookingIllustration: View {
    let stepID: String
    let recipeID: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startDate = Date()

    private var heated: Bool {
        ["preheat-and-wash", "preheat-toast", "bake-fries", "finish-fries", "cook-beef", "heat-water", "boil-pasta", "lemon-sauce", "toss-pasta", "bake-toast", "toast-buns"].contains(stepID)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: ProcessInfo.processInfo.isLowPowerModeEnabled ? 1.0 / 30 : 1.0 / 60,
                                paused: reduceMotion || scenePhase != .active)) { timeline in
            let heatStrength: Double = heated && !reduceMotion ? 1 : 0
            let time = reduceMotion ? 2.4 : max(0, timeline.date.timeIntervalSince(startDate))
            Canvas { context, size in
                var sketch = KitchenSketch(context: context, size: size)
                sketch.gesture(stepID: stepID, recipeID: recipeID, time: time)
            }
            .colorEffect(ShaderLibrary.sketchPaper())
            .visualEffect { content, proxy in
                content.distortionEffect(ShaderLibrary.kitchenHeat(.float2(proxy.size), .float(time), .float(heatStrength)), maxSampleOffset: CGSize(width: 1, height: 0))
            }
            .accessibilityHidden(true)
        }
        .onChange(of: stepID) { _, _ in startDate = .now }
        .onChange(of: scenePhase) { _, phase in if phase == .active { startDate = .now } }
    }

}

private enum SketchColor {
    static let ink = Color(red: 0.29, green: 0.28, blue: 0.23)
    static let paper = Color(red: 0.99, green: 0.98, blue: 0.95)
    static let porcelain = Color(red: 0.97, green: 0.97, blue: 0.93)
    static let ochre = Color(red: 0.87, green: 0.67, blue: 0.36)
    static let butter = Color(red: 0.96, green: 0.82, blue: 0.53)
    static let paleButter = Color(red: 0.99, green: 0.90, blue: 0.69)
    static let toast = Color(red: 0.72, green: 0.47, blue: 0.29)
    static let tomato = Color(red: 0.78, green: 0.36, blue: 0.28)
    static let tomatoLight = Color(red: 0.90, green: 0.56, blue: 0.43)
    static let sage = Color(red: 0.58, green: 0.68, blue: 0.47)
    static let leaf = Color(red: 0.38, green: 0.51, blue: 0.34)
    static let meat = Color(red: 0.47, green: 0.32, blue: 0.24)
    static let water = Color(red: 0.65, green: 0.76, blue: 0.78)
    static let steel = Color(red: 0.88, green: 0.89, blue: 0.85)
    static let shadow = Color(red: 0.46, green: 0.43, blue: 0.34).opacity(0.08)
}

private struct KitchenSketch {
    var context: GraphicsContext

    init(context: GraphicsContext, size: CGSize) {
        self.context = context
        let scale = min(size.width / 360, size.height / 240)
        self.context.translateBy(x: (size.width - 360 * scale) / 2, y: (size.height - 240 * scale) / 2)
        self.context.scaleBy(x: scale, y: scale)
    }

    private init(context: GraphicsContext) {
        self.context = context
    }

    private func translated(_ x: CGFloat, _ y: CGFloat, scale: CGFloat = 1, angle: Double = 0) -> KitchenSketch {
        var copy = KitchenSketch(context: context)
        copy.context.translateBy(x: x, y: y)
        copy.context.rotate(by: .degrees(angle))
        copy.context.scaleBy(x: scale, y: scale)
        return copy
    }

    private mutating func shape(_ path: Path, fill: Color? = nil, line: Color = SketchColor.ink, width: CGFloat = 1.5) {
        if let fill { context.fill(path, with: .color(fill)) }
        if width > 0 { context.stroke(path, with: .color(line), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)) }
    }

    private mutating func oval(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, fill: Color? = nil, line: Color = SketchColor.ink, stroke: CGFloat = 1.5) {
        shape(Path(ellipseIn: CGRect(x: x, y: y, width: width, height: height)), fill: fill, line: line, width: stroke)
    }

    private mutating func line(_ points: [(CGFloat, CGFloat)], color: Color = SketchColor.ink, width: CGFloat = 1.5, closed: Bool = false, fill: Color? = nil) {
        guard let first = points.first else { return }
        var path = Path()
        path.move(to: CGPoint(x: first.0, y: first.1))
        for point in points.dropFirst() { path.addLine(to: CGPoint(x: point.0, y: point.1)) }
        if closed { path.closeSubpath() }
        shape(path, fill: fill, line: color, width: width)
    }

    mutating func meal(recipeID: String) {
        if recipeID.contains("pasta") {
            pastaMeal()
        } else if recipeID.contains("toast") {
            toastMeal()
        } else {
            burgerMeal()
        }
    }

    private mutating func plate() {
        oval(48, 186, 269, 29, fill: SketchColor.shadow, stroke: 0)
        var rim = Path()
        rim.move(to: CGPoint(x: 34, y: 172))
        rim.addCurve(to: CGPoint(x: 326, y: 171), control1: CGPoint(x: 41, y: 134), control2: CGPoint(x: 301, y: 130))
        rim.addCurve(to: CGPoint(x: 34, y: 172), control1: CGPoint(x: 345, y: 222), control2: CGPoint(x: 38, y: 227))
        shape(rim, fill: SketchColor.porcelain, line: SketchColor.ink.opacity(0.55), width: 1.2)
        var inner = Path()
        inner.move(to: CGPoint(x: 60, y: 179))
        inner.addCurve(to: CGPoint(x: 303, y: 177), control1: CGPoint(x: 72, y: 210), control2: CGPoint(x: 280, y: 210))
        shape(inner, line: SketchColor.ink.opacity(0.24), width: 1)
    }

    private mutating func burgerMeal() {
        plate()
        let fries: [(CGFloat, CGFloat, Double, CGFloat)] = [
            (235, 105, -21, 75), (263, 109, 15, 72), (275, 126, 28, 68),
            (249, 120, -6, 83), (229, 126, -28, 71), (293, 135, 47, 57),
            (257, 140, 37, 69), (269, 137, 1, 71), (236, 142, -8, 54)
        ]
        for (index, fry) in fries.enumerated() {
            var piece = translated(fry.0, fry.1, angle: fry.2)
            piece.fry(length: fry.3, shade: index % 3)
        }
        var food = translated(53, 49, scale: 1.05)
        food.burger()
        line([(267, 194), (271, 191)], color: SketchColor.ochre, width: 2)
        line([(278, 188), (282, 190)], color: SketchColor.ochre, width: 2)
        var herb = translated(218, 195, scale: 0.48, angle: -25)
        herb.leaf()
    }

    private mutating func fry(length: CGFloat = 65, shade: Int = 0) {
        line([(0, 1), (10, -1), (12, length - 3), (7, length), (-1, length - 2), (0, 1)], width: 1.1, closed: true, fill: shade == 0 ? SketchColor.butter : SketchColor.paleButter)
        line([(8, 5), (9, length - 7)], color: SketchColor.ochre.opacity(0.72), width: 1.2)
        line([(1, 2), (5, 4), (10, 0)], color: SketchColor.ochre, width: 0.8)
    }

    private mutating func burger(separation: CGFloat = 0, assemblyTime: Double? = nil) {
        var bottom = Path()
        bottom.move(to: CGPoint(x: 5, y: 114))
        bottom.addCurve(to: CGPoint(x: 176, y: 115), control1: CGPoint(x: 53, y: 105), control2: CGPoint(x: 139, y: 106))
        bottom.addCurve(to: CGPoint(x: 168, y: 141), control1: CGPoint(x: 180, y: 127), control2: CGPoint(x: 176, y: 137))
        bottom.addCurve(to: CGPoint(x: 20, y: 141), control1: CGPoint(x: 135, y: 153), control2: CGPoint(x: 41, y: 152))
        bottom.addCurve(to: CGPoint(x: 5, y: 114), control1: CGPoint(x: 9, y: 136), control2: CGPoint(x: 6, y: 124))
        shape(bottom, fill: SketchColor.butter)
        var bottomMark = Path()
        bottomMark.move(to: CGPoint(x: 22, y: 133))
        bottomMark.addQuadCurve(to: CGPoint(x: 157, y: 134), control: CGPoint(x: 87, y: 148))
        shape(bottomMark, line: SketchColor.ochre, width: 1)

        var pattySketch = translated(0, assemblyTime.map { CGFloat(-75 * (1 - ease(($0 - 0 * 0.65) / 0.65))) } ?? -separation * 0.25)
        pattySketch.context.opacity = assemblyTime.map { ease(($0 - 0 * 0.65) / 0.20) } ?? 1
        pattySketch.patty()

        var cheeseSketch = translated(0, assemblyTime.map { CGFloat(-75 * (1 - ease(($0 - 1 * 0.65) / 0.65))) } ?? -separation * 0.5)
        cheeseSketch.context.opacity = assemblyTime.map { ease(($0 - 1 * 0.65) / 0.20) } ?? 1
        cheeseSketch.line([(3, 101), (31, 93), (144, 91), (179, 100), (156, 110), (124, 106), (99, 121), (72, 109), (16, 115)], closed: true, fill: SketchColor.butter)
        cheeseSketch.line([(13, 102), (41, 103), (68, 107)], color: SketchColor.ochre.opacity(0.6), width: 1)

        var tomatoSketch = translated(0, assemblyTime.map { CGFloat(-75 * (1 - ease(($0 - 2 * 0.65) / 0.65))) } ?? -separation * 0.75)
        tomatoSketch.context.opacity = assemblyTime.map { ease(($0 - 2 * 0.65) / 0.20) } ?? 1
        tomatoSketch.oval(10, 82, 164, 22, fill: SketchColor.tomato)
        tomatoSketch.line([(22, 94), (51, 99), (84, 99)], color: SketchColor.tomatoLight, width: 2)

        var lettuceSketch = translated(0, assemblyTime.map { CGFloat(-75 * (1 - ease(($0 - 3 * 0.65) / 0.65))) } ?? -separation * 1)
        lettuceSketch.context.opacity = assemblyTime.map { ease(($0 - 3 * 0.65) / 0.20) } ?? 1
        lettuceSketch.line([(4, 81), (13, 72), (28, 77), (41, 70), (59, 76), (75, 69), (92, 76), (110, 70), (124, 75), (143, 71), (157, 77), (175, 74), (184, 85), (172, 87), (164, 95), (149, 90), (135, 96), (119, 88), (102, 97), (85, 91), (66, 95), (49, 88), (33, 94), (22, 87), (6, 91)], closed: true, fill: SketchColor.sage)
        lettuceSketch.line([(15, 83), (39, 83), (59, 86), (86, 81), (112, 84), (141, 82), (166, 84)], color: SketchColor.leaf, width: 1)

        var topSketch = translated(0, assemblyTime.map { CGFloat(-75 * (1 - ease(($0 - 4 * 0.65) / 0.65))) } ?? -separation * 1.35)
        topSketch.context.opacity = assemblyTime.map { ease(($0 - 4 * 0.65) / 0.20) } ?? 1
        var top = Path()
        top.move(to: CGPoint(x: 4, y: 70))
        top.addCurve(to: CGPoint(x: 81, y: 14), control1: CGPoint(x: 9, y: 35), control2: CGPoint(x: 45, y: 13))
        top.addCurve(to: CGPoint(x: 177, y: 65), control1: CGPoint(x: 130, y: 10), control2: CGPoint(x: 168, y: 29))
        top.addCurve(to: CGPoint(x: 172, y: 79), control1: CGPoint(x: 183, y: 74), control2: CGPoint(x: 180, y: 77))
        top.addCurve(to: CGPoint(x: 13, y: 80), control1: CGPoint(x: 132, y: 91), control2: CGPoint(x: 47, y: 91))
        top.addCurve(to: CGPoint(x: 4, y: 70), control1: CGPoint(x: 5, y: 79), control2: CGPoint(x: 1, y: 74))
        topSketch.shape(top, fill: SketchColor.butter)
        var highlight = Path()
        highlight.move(to: CGPoint(x: 18, y: 60))
        highlight.addCurve(to: CGPoint(x: 144, y: 39), control1: CGPoint(x: 40, y: 13), control2: CGPoint(x: 104, y: 14))
        topSketch.shape(highlight, line: SketchColor.paleButter, width: 5)
        var edge = Path()
        edge.move(to: CGPoint(x: 16, y: 73))
        edge.addQuadCurve(to: CGPoint(x: 164, y: 73), control: CGPoint(x: 88, y: 88))
        topSketch.shape(edge, line: SketchColor.ochre, width: 1)
        let seeds: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(40, 51, 44, 48), (60, 35, 63, 39), (87, 31, 92, 29), (117, 40, 121, 43), (140, 55, 145, 56), (111, 63, 115, 60), (74, 57, 77, 60), (48, 69, 52, 68), (94, 73, 97, 69), (149, 70, 153, 68)]
        for seed in seeds {
            topSketch.line([(seed.0, seed.1), (seed.2, seed.3)], color: SketchColor.paper, width: 2.8)
            topSketch.line([(seed.0, seed.1 + 1.8), (seed.2, seed.3 + 1.8)], color: SketchColor.ochre.opacity(0.45), width: 0.55)
        }
    }

    private mutating func patty() {
        var path = Path()
        path.move(to: CGPoint(x: 8, y: 106))
        path.addCurve(to: CGPoint(x: 173, y: 106), control1: CGPoint(x: 36, y: 94), control2: CGPoint(x: 143, y: 98))
        path.addCurve(to: CGPoint(x: 170, y: 124), control1: CGPoint(x: 184, y: 112), control2: CGPoint(x: 181, y: 122))
        path.addCurve(to: CGPoint(x: 11, y: 125), control1: CGPoint(x: 122, y: 135), control2: CGPoint(x: 38, y: 133))
        path.addCurve(to: CGPoint(x: 8, y: 106), control1: CGPoint(x: 0, y: 121), control2: CGPoint(x: 0, y: 112))
        shape(path, fill: SketchColor.meat)
        for x in stride(from: 21, through: 154, by: 17) {
            line([(CGFloat(x), 121), (CGFloat(x + 5), 124)], color: SketchColor.ochre.opacity(0.62), width: 1)
        }
    }

    private mutating func leaf() {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addCurve(to: CGPoint(x: 34, y: -26), control1: CGPoint(x: -4, y: -24), control2: CGPoint(x: 12, y: -34))
        path.addCurve(to: CGPoint(x: 0, y: 0), control1: CGPoint(x: 32, y: -3), control2: CGPoint(x: 17, y: 8))
        shape(path, fill: SketchColor.sage, width: 1.2)
        line([(0, 0), (28, -22)], color: SketchColor.leaf, width: 1)
        line([(12, -10), (10, -21)], color: SketchColor.leaf.opacity(0.6), width: 0.7)
        line([(18, -15), (28, -13)], color: SketchColor.leaf.opacity(0.6), width: 0.7)
    }

    private mutating func pastaMeal() {
        oval(72, 190, 217, 22, fill: SketchColor.shadow, stroke: 0)
        var bowl = Path()
        bowl.move(to: CGPoint(x: 47, y: 139))
        bowl.addCurve(to: CGPoint(x: 312, y: 139), control1: CGPoint(x: 105, y: 119), control2: CGPoint(x: 256, y: 118))
        bowl.addCurve(to: CGPoint(x: 257, y: 202), control1: CGPoint(x: 305, y: 170), control2: CGPoint(x: 281, y: 197))
        bowl.addCurve(to: CGPoint(x: 103, y: 202), control1: CGPoint(x: 218, y: 215), control2: CGPoint(x: 139, y: 214))
        bowl.addCurve(to: CGPoint(x: 47, y: 139), control1: CGPoint(x: 74, y: 193), control2: CGPoint(x: 55, y: 170))
        shape(bowl, fill: SketchColor.porcelain)
        oval(47, 104, 265, 81, fill: SketchColor.paper, stroke: 1.3)
        oval(64, 115, 231, 54, fill: SketchColor.paleButter, line: SketchColor.ochre.opacity(0.55), stroke: 0.9)
        let ribbons: [(CGFloat, CGFloat, Double)] = [
            (100, 129, -24), (143, 117, 16), (183, 120, -12), (225, 129, 27),
            (258, 142, -16), (84, 147, 5), (127, 141, -9), (167, 137, 31),
            (206, 143, -29), (238, 156, 20), (108, 159, -7), (147, 158, 24),
            (183, 160, -19), (216, 164, 2), (159, 169, -13)
        ]
        for (index, position) in ribbons.enumerated() {
            var noodle = translated(position.0, position.1, scale: index % 3 == 0 ? 0.9 : 1, angle: position.2)
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: -13, y: 3))
            ribbon.addCurve(to: CGPoint(x: 20, y: -5), control1: CGPoint(x: -23, y: -13), control2: CGPoint(x: 9, y: -19))
            ribbon.addCurve(to: CGPoint(x: -10, y: 11), control1: CGPoint(x: 33, y: 10), control2: CGPoint(x: 4, y: 17))
            ribbon.addCurve(to: CGPoint(x: 12, y: -1), control1: CGPoint(x: -28, y: 1), control2: CGPoint(x: -2, y: -11))
            noodle.shape(ribbon, line: SketchColor.ochre, width: 7)
            noodle.shape(ribbon, line: SketchColor.butter, width: 4.7)
            noodle.shape(ribbon.offsetBy(dx: -1.2, dy: -1), line: SketchColor.paleButter, width: 1)
        }
        var lemon = translated(248, 91, scale: 0.84, angle: 21)
        lemon.lemonSlice()
        var basil = translated(178, 111, scale: 0.75, angle: -24)
        basil.leaf()
        var basil2 = translated(179, 110, scale: 0.6, angle: -108)
        basil2.leaf()
        for fleck in [(124.0, 116.0), (231.0, 140.0), (208.0, 163.0), (149.0, 151.0), (94.0, 143.0)] {
            line([(fleck.0, fleck.1), (fleck.0 + 3, fleck.1 + 2)], color: SketchColor.leaf, width: 1.8)
        }
        var rim = Path()
        rim.move(to: CGPoint(x: 68, y: 177))
        rim.addQuadCurve(to: CGPoint(x: 293, y: 176), control: CGPoint(x: 187, y: 213))
        shape(rim, line: SketchColor.ink.opacity(0.24), width: 0.85)
    }

    private mutating func lemonSlice() {
        var lemon = Path()
        lemon.move(to: CGPoint(x: 0, y: 0))
        lemon.addCurve(to: CGPoint(x: 66, y: 0), control1: CGPoint(x: 2, y: 51), control2: CGPoint(x: 61, y: 51))
        lemon.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: 31, y: -7))
        shape(lemon, fill: SketchColor.butter, width: 1.2)
        var inside = Path()
        inside.move(to: CGPoint(x: 7, y: 3))
        inside.addCurve(to: CGPoint(x: 59, y: 3), control1: CGPoint(x: 12, y: 40), control2: CGPoint(x: 52, y: 42))
        shape(inside, line: SketchColor.paper, width: 3)
        for end in [(15.0, 21.0), (30.0, 30.0), (47.0, 25.0)] {
            line([(33, 4), (end.0, end.1)], color: SketchColor.paper, width: 2)
        }
    }

    private mutating func toastMeal() {
        plate()
        var rear = translated(128, 86, scale: 0.9, angle: -8)
        rear.toast()
        var front = translated(80, 92, scale: 1.07, angle: 9)
        front.toast()
        var basil = translated(279, 189, scale: 0.58, angle: -69)
        basil.leaf()
        oval(281, 183, 3, 3, fill: SketchColor.ochre, stroke: 0)
        oval(269, 200, 2, 2, fill: SketchColor.ochre, stroke: 0)
    }

    private mutating func toast() {
        var bread = Path()
        bread.move(to: CGPoint(x: 0, y: 11))
        bread.addCurve(to: CGPoint(x: 136, y: -8), control1: CGPoint(x: 16, y: -12), control2: CGPoint(x: 94, y: -28))
        bread.addCurve(to: CGPoint(x: 146, y: 79), control1: CGPoint(x: 163, y: 3), control2: CGPoint(x: 167, y: 53))
        bread.addCurve(to: CGPoint(x: 14, y: 98), control1: CGPoint(x: 118, y: 102), control2: CGPoint(x: 43, y: 114))
        bread.addCurve(to: CGPoint(x: 0, y: 11), control1: CGPoint(x: -4, y: 79), control2: CGPoint(x: -8, y: 43))
        shape(bread, fill: SketchColor.ochre)
        var crumb = translated(7, 4, scale: 0.89)
        crumb.shape(bread, fill: SketchColor.paleButter, line: SketchColor.toast.opacity(0.7), width: 1)
        for point in [(16.0, 33.0), (56.0, 3.0), (127.0, 63.0), (24.0, 84.0), (91.0, 84.0)] {
            oval(point.0, point.1, 4, 2, fill: SketchColor.ochre.opacity(0.6), stroke: 0)
        }
        for tomato in [(35.0, 30.0), (101.0, 31.0), (66.0, 69.0)] {
            var tomatoDrawing = translated(tomato.0, tomato.1, scale: 0.65)
            tomatoDrawing.tomatoSlice()
        }
        for cheese in [(26.0, 46.0), (67.0, 25.0), (98.0, 59.0)] {
            oval(cheese.0, cheese.1, 35, 25, fill: SketchColor.paper, line: SketchColor.ink.opacity(0.65), stroke: 1)
            var vein = Path()
            vein.move(to: CGPoint(x: cheese.0 + 9, y: cheese.1 + 7))
            vein.addQuadCurve(to: CGPoint(x: cheese.0 + 29, y: cheese.1 + 14), control: CGPoint(x: cheese.0 + 17, y: cheese.1 + 3))
            shape(vein, line: SketchColor.ochre.opacity(0.3), width: 0.7)
        }
        var leaf1 = translated(51, 49, scale: 0.65, angle: -5)
        leaf1.leaf()
        var leaf2 = translated(107, 76, scale: 0.58, angle: -93)
        leaf2.leaf()
    }

    private mutating func tomatoSlice() {
        oval(-29, -22, 62, 48, fill: SketchColor.tomato, stroke: 1.3)
        oval(-24, -18, 52, 39, fill: SketchColor.tomatoLight, line: SketchColor.tomato, stroke: 1)
        for angle in [0.0, 120.0, 240.0] {
            var segment = translated(2, 1, angle: angle)
            segment.line([(0, 0), (-7, -13), (10, -12), (0, 0)], color: SketchColor.tomato, width: 1, closed: true, fill: SketchColor.tomato.opacity(0.4))
            segment.line([(0, -9), (2, -6)], color: SketchColor.paleButter, width: 1.8)
        }
    }

    mutating func gesture(stepID: String, recipeID: String, time: TimeInterval) {
        switch stepID {
        case "preheat-and-wash", "preheat-toast": oven(time: time, preheating: true)
        case "cut-fries": chopping(time: time, isTomato: false)
        case "dry-fries":
            let phase = time.truncatingRemainder(dividingBy: 9)
            if phase < 4 { wash(time: phase) } else { drying(time: phase - 4) }
        case "prepare-toppings", "slice-tomatoes": chopping(time: time, isTomato: true)
        case "bake-fries", "finish-fries": oven(time: time)
        case "bake-toast": oven(time: time, toast: true)
        case "toast-buns": pan(time: time, buns: true)
        case "cook-beef": pan(time: time)
        case "assemble-and-serve": assembly(time: time)
        case "zest-lemon": lemonGesture(time: time)
        case "lemon-sauce": sauce(time: time)
        case "toss-pasta": tossPasta(time: time)
        case "build-toast": toastAssembly(time: time)
        case "dress-tomatoes": dressTomatoes(time: time)
        case "serve-pasta", "serve-toast": meal(recipeID: recipeID)
        default: pot(time: time)
        }
    }

    private mutating func board() {
        oval(73, 189, 213, 21, fill: SketchColor.shadow, stroke: 0)
        var board = Path()
        board.move(to: CGPoint(x: 52, y: 118))
        board.addQuadCurve(to: CGPoint(x: 61, y: 108), control: CGPoint(x: 52, y: 110))
        board.addLine(to: CGPoint(x: 298, y: 108))
        board.addQuadCurve(to: CGPoint(x: 308, y: 119), control: CGPoint(x: 307, y: 109))
        board.addLine(to: CGPoint(x: 315, y: 183))
        board.addQuadCurve(to: CGPoint(x: 303, y: 198), control: CGPoint(x: 319, y: 196))
        board.addLine(to: CGPoint(x: 58, y: 198))
        board.addQuadCurve(to: CGPoint(x: 47, y: 186), control: CGPoint(x: 44, y: 197))
        board.closeSubpath()
        shape(board, fill: SketchColor.paleButter.opacity(0.5), line: SketchColor.ochre.opacity(0.7), width: 1.2)
        line([(60, 188), (301, 189)], color: SketchColor.ochre.opacity(0.3), width: 1)
        line([(67, 117), (153, 118)], color: SketchColor.ochre.opacity(0.22), width: 1)
        line([(212, 181), (292, 182)], color: SketchColor.ochre.opacity(0.2), width: 1)
    }

    /// Smooth contact, delayed separation and a hold at the end make the cut readable.
    private func ease(_ value: Double) -> Double {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }

    private mutating func chopping(time: TimeInterval, isTomato: Bool) {
        board()
        let cycle = time.truncatingRemainder(dividingBy: 8.8)
        let cut = min(5, Int(cycle / 1.2))
        let phase = min(1, (cycle - Double(cut) * 1.2) / 1.2)
        let contact = ease((phase - 0.2) / 0.22)
        let lift = ease((phase - 0.58) / 0.28)
        let knifeY = CGFloat(-39 * (1 - contact + lift))
        let foodColor = isTomato ? SketchColor.tomatoLight : SketchColor.paleButter
        let edgeColor = isTomato ? SketchColor.tomato : SketchColor.ochre
        // Each strip is a real piece; nothing remains underneath separated slices.
        for i in 0..<6 {
            let progress = i < cut ? 1 : i == cut ? ease((phase - 0.46) / 0.35) : 0
            let shift = CGFloat(progress * Double(6 + (6 - i) * 2))
            let x = CGFloat(118 + i * 19) - shift * 0.34
            let y = 126 + shift
            var piece = translated(x, y, angle: progress * Double(i - 3) * 1.3)
            if isTomato {
                piece.oval(0, 0, 18, 54, fill: foodColor, line: edgeColor, stroke: 1.2)
                piece.oval(4, 7, 9, 37, fill: SketchColor.tomato.opacity(0.45), stroke: 0)
                for j in 0..<4 { piece.line([(8, CGFloat(13 + j * 8)), (10, CGFloat(16 + j * 8))], color: SketchColor.paleButter, width: 1.8) }
            } else {
                piece.line([(0, 4), (13, 0), (18, 7), (18, 57), (4, 62), (0, 55)], color: edgeColor, width: 1, closed: true, fill: foodColor)
                piece.line([(13, 1), (13, 53), (4, 61)], color: edgeColor.opacity(0.65), width: 1)
                piece.line([(3, 8), (3, 50)], color: .white.opacity(0.75), width: 2)
            }
        }
        // Long chef's blade seen at three-quarter angle; the edge lands on the board.
        let bladeX = CGFloat(131 + cut * 19)
        var knife = translated(bladeX, knifeY, angle: -4 + 4 * contact - 2 * lift)
        knife.oval(-31, 178 - knifeY, 78, 8, fill: SketchColor.shadow.opacity(0.4), stroke: 0)
        var blade = Path()
        blade.move(to: CGPoint(x: -4, y: 110))
        blade.addLine(to: CGPoint(x: 21, y: 107))
        blade.addLine(to: CGPoint(x: 24, y: 165))
        blade.addQuadCurve(to: CGPoint(x: -5, y: 192), control: CGPoint(x: 21, y: 187))
        blade.closeSubpath()
        knife.shape(blade, fill: SketchColor.steel, line: SketchColor.ink.opacity(0.8), width: 1.1)
        knife.line([(1, 115), (2, 182)], color: .white, width: 3)
        knife.line([(17, 118), (19, 163), (3, 185)], color: SketchColor.water.opacity(0.55), width: 1)
        knife.shape(Path(roundedRect: CGRect(x: -4, y: 59, width: 21, height: 49), cornerRadius: 6), fill: SketchColor.meat, width: 1)
        for y in [70.0, 96.0] { knife.oval(4, y, 4, 4, fill: SketchColor.steel, stroke: 0) }
    }

    private mutating func drying(time: TimeInterval) {
        board()
        for i in 0..<7 {
            var piece = translated(CGFloat(112 + i * 17), 128, scale: 0.7, angle: 8)
            piece.fry(length: 65, shade: 1)
        }
        let x = CGFloat(112 + sin(time * 1.5) * 24)
        let cloth = Path(roundedRect: CGRect(x: x, y: 121, width: 129, height: 64), cornerRadius: 10)
        shape(cloth, fill: SketchColor.paper.opacity(0.96), line: SketchColor.ink.opacity(0.45), width: 1)
        for i in 0..<6 {
            line([(x + CGFloat(i * 19 + 7), 124), (x + CGFloat(i * 19 + 7), 181)], color: SketchColor.water.opacity(0.38), width: 1)
        }
        for i in 0..<3 {
            line([(x + 3, CGFloat(132 + i * 19)), (x + 123, CGFloat(132 + i * 19))], color: SketchColor.water.opacity(0.38), width: 1)
        }
    }

    private mutating func sauce(time: TimeInterval) {
        pot(time: time)
        let angle = time * 1.8
        let x = CGFloat(180 + cos(angle) * 46)
        let y = CGFloat(110 + sin(angle) * 11)
        oval(x - 10, y - 4, 24, 10, fill: SketchColor.ochre, stroke: 1)
        line([(x + 5, y), (x + 49, y - 62)], color: SketchColor.toast, width: 7)
        line([(x + 4, y - 1), (x + 48, y - 62)], color: SketchColor.butter, width: 2)
    }

    private mutating func tossPasta(time: TimeInterval) {
        pastaMeal()
        let angle = time * 1.4
        let x = CGFloat(172 + cos(angle) * 34)
        let y = CGFloat(129 + sin(angle) * 10)
        line([(x, y), (x + 59, y - 61)], color: SketchColor.steel, width: 6)
        for i in 0..<3 {
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: x + CGFloat(i * 4), y: y - 5))
            ribbon.addCurve(to: CGPoint(x: x - 20 + CGFloat(i * 7), y: 158), control1: CGPoint(x: x - 25, y: y + 5), control2: CGPoint(x: x + 24, y: 146))
            shape(ribbon, line: SketchColor.ochre, width: 4)
            shape(ribbon, line: SketchColor.paleButter, width: 2)
        }
    }

    private mutating func dressTomatoes(time: TimeInterval) {
        oval(77, 182, 212, 21, fill: SketchColor.shadow, stroke: 0)
        oval(75, 117, 214, 80, fill: SketchColor.porcelain, stroke: 1)
        oval(83, 119, 198, 53, fill: SketchColor.paper, stroke: 1)
        for i in 0..<9 {
            let x = CGFloat(105 + i % 5 * 31)
            let y = CGFloat(126 + i / 5 * 20)
            var tomato = translated(x, y, angle: sin(time + Double(i)) * 5)
            tomato.line([(0, 0), (19, -4), (23, 12), (3, 17)], color: SketchColor.tomato, width: 1, closed: true, fill: SketchColor.tomatoLight)
        }
        let phase = time.truncatingRemainder(dividingBy: 4) / 4
        var herb = translated(180, CGFloat(65 + ease(phase) * 89), scale: 0.6, angle: phase * 90)
        herb.context.opacity = sin(phase * .pi)
        herb.leaf()
    }

    private mutating func toastAssembly(time: TimeInterval) {
        var bread = translated(99, 87, scale: 1.1)
        bread.toast()
        for i in 0..<3 {
            let phase = (time * 0.4 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            var herb = translated(CGFloat(134 + i * 31), CGFloat(44 + phase * 88), scale: 0.65, angle: phase * 50)
            herb.context.opacity = min(1, phase * 5)
            herb.leaf()
        }
    }

    private mutating func potato(x: CGFloat, y: CGFloat, scale: CGFloat = 1) {
        var potato = translated(x, y, scale: scale, angle: -8)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 26))
        path.addCurve(to: CGPoint(x: 38, y: 0), control1: CGPoint(x: -4, y: 10), control2: CGPoint(x: 18, y: -5))
        path.addCurve(to: CGPoint(x: 82, y: 33), control1: CGPoint(x: 61, y: -1), control2: CGPoint(x: 83, y: 16))
        path.addCurve(to: CGPoint(x: 33, y: 54), control1: CGPoint(x: 80, y: 56), control2: CGPoint(x: 46, y: 62))
        path.addCurve(to: CGPoint(x: 0, y: 26), control1: CGPoint(x: 17, y: 52), control2: CGPoint(x: -3, y: 44))
        potato.shape(path, fill: SketchColor.butter)
        for p in [(16.0, 27.0), (48.0, 14.0), (60.0, 36.0), (31.0, 42.0)] {
            potato.line([(p.0, p.1), (p.0 + 2, p.1 - 1)], color: SketchColor.toast.opacity(0.75), width: 1.3)
        }
        var shine = Path()
        shine.move(to: CGPoint(x: 11, y: 19))
        shine.addQuadCurve(to: CGPoint(x: 38, y: 7), control: CGPoint(x: 21, y: 5))
        potato.shape(shine, line: SketchColor.paleButter, width: 3)
    }

    private mutating func wash(time: TimeInterval) {
        oval(84, 195, 198, 16, fill: SketchColor.shadow, stroke: 0)
        var bowl = Path()
        bowl.move(to: CGPoint(x: 73, y: 137))
        bowl.addCurve(to: CGPoint(x: 287, y: 137), control1: CGPoint(x: 120, y: 118), control2: CGPoint(x: 253, y: 118))
        bowl.addCurve(to: CGPoint(x: 240, y: 198), control1: CGPoint(x: 284, y: 163), control2: CGPoint(x: 261, y: 191))
        bowl.addQuadCurve(to: CGPoint(x: 122, y: 198), control: CGPoint(x: 181, y: 215))
        bowl.addQuadCurve(to: CGPoint(x: 73, y: 137), control: CGPoint(x: 79, y: 176))
        shape(bowl, fill: SketchColor.porcelain)
        oval(74, 119, 212, 48, fill: SketchColor.water.opacity(0.15), stroke: 1.2)
        potato(x: 104, y: 112, scale: 0.84)
        potato(x: 177, y: 122, scale: 0.77)
        for index in 0..<7 {
            let phase = (time * 0.9 + Double(index) * 0.17).truncatingRemainder(dividingBy: 1)
            let x = CGFloat(123 + index * 16)
            let y = CGFloat(36 + phase * 96)
            var droplet = Path()
            droplet.move(to: CGPoint(x: x, y: y))
            droplet.addQuadCurve(to: CGPoint(x: x + 2, y: y + 10), control: CGPoint(x: x - 5, y: y + 9))
            droplet.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x + 7, y: y + 9))
            shape(droplet, fill: SketchColor.water.opacity(0.5), line: SketchColor.water, width: 0.8)
        }
        var rim = Path()
        rim.move(to: CGPoint(x: 86, y: 150))
        rim.addQuadCurve(to: CGPoint(x: 272, y: 150), control: CGPoint(x: 180, y: 184))
        shape(rim, line: SketchColor.ink.opacity(0.42), width: 0.8)
        for index in 0..<8 {
            oval(CGFloat(114 + index * 19), CGFloat(181 + abs(index - 3)), 2, 3, fill: SketchColor.ink.opacity(0.4), stroke: 0)
        }
    }

    private mutating func steam(time: TimeInterval, x: CGFloat, y: CGFloat, count: Int = 3) {
        for index in 0..<count {
            let phase = (time * 0.34 + Double(index) * 0.24).truncatingRemainder(dividingBy: 1)
            let rise = CGFloat(phase) * 14
            let bend = CGFloat(sin(time * 1.5 + Double(index))) * 4
            let startX = x + CGFloat(index * 27)
            var wisp = Path()
            wisp.move(to: CGPoint(x: startX, y: y - rise))
            wisp.addCurve(to: CGPoint(x: startX + bend, y: y - 36 - rise), control1: CGPoint(x: startX - 11, y: y - 12 - rise), control2: CGPoint(x: startX + 12, y: y - 22 - rise))
            shape(wisp, line: SketchColor.ochre.opacity(0.16 + 0.30 * sin(phase * .pi)), width: 1.4)
        }
    }

    private mutating func oven(time: TimeInterval, preheating: Bool = false, toast: Bool = false) {
        let cycle = time.truncatingRemainder(dividingBy: 9)
        let opening = preheating ? 0 : 1 - ease((cycle - 2.4) / 1.0)
        oval(76, 205, 215, 13, fill: SketchColor.shadow, stroke: 0)
        // A side plane, front panel and recessed glass give the appliance a clear silhouette.
        line([(273, 44), (287, 53), (287, 193), (274, 201)], color: SketchColor.ink.opacity(0.65), closed: true, fill: SketchColor.steel)
        shape(Path(roundedRect: CGRect(x: 79, y: 44, width: 197, height: 158), cornerRadius: 12), fill: SketchColor.porcelain, width: 1.25)
        line([(80, 82), (275, 82)], color: SketchColor.ink.opacity(0.35), width: 1)
        for x in [104.0, 250.0] {
            oval(x - 9, 55, 18, 18, fill: SketchColor.paper, stroke: 1)
            oval(x - 6, 58, 12, 12, fill: SketchColor.steel.opacity(0.4), stroke: 0)
        }
        let dialAngle = preheating ? ease(cycle / 1.5) * 135 : 135
        var dial = translated(104, 64, angle: dialAngle)
        dial.line([(0, 0), (0, -6)], color: SketchColor.ink, width: 1.7)
        line([(250, 64), (254, 60)], width: 1.2)
        shape(Path(roundedRect: CGRect(x: 157, y: 56, width: 40, height: 17), cornerRadius: 4), fill: SketchColor.ink.opacity(0.07), width: 0)
        for i in 0..<3 {
            line([(CGFloat(164 + i * 10), 62), (CGFloat(169 + i * 10), 62)], color: SketchColor.leaf.opacity(0.7), width: 1.7)
            line([(CGFloat(164 + i * 10), 67), (CGFloat(169 + i * 10), 67)], color: SketchColor.leaf.opacity(0.7), width: 1.7)
        }
        let cavity = Path(roundedRect: CGRect(x: 92, y: 94, width: 171, height: 92), cornerRadius: 8)
        shape(cavity, fill: SketchColor.meat.opacity(0.12), line: SketchColor.ink.opacity(0.7), width: 1)
        for y in [127.0, 151.0, 173.0] { line([(103, y), (253, y)], color: SketchColor.ink.opacity(0.2), width: 1) }
        let warmth = preheating ? ease(cycle / 3) : ease((cycle - 3) / 3)
        shape(cavity, fill: SketchColor.butter.opacity(warmth * 0.20), width: 0)
        if !preheating {
            let slide = 1 - ease((cycle - 0.4) / 1.8)
            var tray = translated(0, CGFloat(slide * 30))
            tray.line([(103, 147), (251, 147), (240, 162), (114, 162)], closed: true, fill: SketchColor.steel)
            if toast {
                for x in [119.0, 177.0] {
                    var slice = tray.translated(x, 126, scale: 0.35)
                    slice.toast()
                }
            } else {
                for i in 0..<9 {
                    var fry = tray.translated(CGFloat(118 + i * 13), CGFloat(136 - i % 2 * 4), scale: 0.48, angle: -55)
                    fry.fry(length: 41, shade: i % 3)
                }
            }
        }
        let topY = CGFloat(94 + opening * 83)
        let bottomY = CGFloat(187 + opening * 29)
        line([(92, topY), (263, topY), (274, bottomY), (82, bottomY)], color: SketchColor.ink.opacity(0.65), width: 1.1, closed: true, fill: SketchColor.paper.opacity(0.25))
        line([(116, topY + 9), (241, topY + 9)], color: SketchColor.ink.opacity(0.75), width: 4)
        line([(115, topY + 12), (241, topY + 12)], color: .white.opacity(0.8), width: 1)
        if opening < 0.1 { line([(103, 109), (118, 173)], color: .white.opacity(0.6), width: 5) }
        line([(103, 180), (252, 180)], color: SketchColor.tomato.opacity(warmth * 0.65), width: 2)
        line([(92, 203), (92, 208)], width: 3)
        line([(263, 203), (263, 208)], width: 3)
    }

    private mutating func pan(time: TimeInterval, buns: Bool = false) {
        oval(60, 181, 229, 19, fill: SketchColor.shadow, stroke: 0)
        line([(253, 146), (312, 121), (321, 129), (263, 163)], width: 1.5, closed: true, fill: SketchColor.meat)
        var vessel = Path()
        vessel.move(to: CGPoint(x: 50, y: 143))
        vessel.addCurve(to: CGPoint(x: 272, y: 140), control1: CGPoint(x: 95, y: 122), control2: CGPoint(x: 230, y: 121))
        vessel.addQuadCurve(to: CGPoint(x: 243, y: 184), control: CGPoint(x: 273, y: 174))
        vessel.addQuadCurve(to: CGPoint(x: 81, y: 184), control: CGPoint(x: 164, y: 205))
        vessel.addQuadCurve(to: CGPoint(x: 50, y: 143), control: CGPoint(x: 50, y: 168))
        shape(vessel, fill: SketchColor.steel, width: 1.6)
        oval(50, 111, 223, 70, fill: SketchColor.porcelain, stroke: 1.5)
        oval(64, 120, 192, 51, fill: SketchColor.ink.opacity(0.04), line: SketchColor.ink.opacity(0.3), stroke: 0.8)
        if buns {
            for x in [84.0, 176.0] {
                oval(x, 130, 68, 29, fill: SketchColor.ochre, stroke: 1)
                oval(x, 126, 68, 26, fill: SketchColor.paleButter, stroke: 1)
                for i in 0..<3 { line([(x + 17 + CGFloat(i * 13), 130), (x + 22 + CGFloat(i * 13), 146)], color: SketchColor.toast.opacity(0.5), width: 2) }
            }
        } else {
            let cycle = time.truncatingRemainder(dividingBy: 7)
            let flip = sin(ease((cycle - 2.2) / 1.2) * .pi)
            var steak = translated(0, CGFloat(-flip * 32))
            steak.context.translateBy(x: 160, y: 142)
            steak.context.scaleBy(x: 1, y: 1 - flip * 0.8)
            steak.context.translateBy(x: -160, y: -142)
            steak.oval(104, 130, 111, 31, fill: SketchColor.meat, stroke: 1.1)
            steak.oval(106, 123, 108, 30, fill: cycle < 2.8 ? SketchColor.toast : SketchColor.meat, stroke: 1.2)
            for i in 0..<5 { steak.line([(CGFloat(119 + i * 17), 129), (CGFloat(130 + i * 17), 145)], color: SketchColor.ochre.opacity(0.6), width: 2) }
            if cycle > 1.3 && cycle < 3.9 {
                var spatula = translated(CGFloat(80 * (1 - ease((cycle - 1.3) / 0.9))), CGFloat(-flip * 20))
                spatula.line([(187, 150), (258, 89)], color: SketchColor.meat, width: 9)
                spatula.line([(155, 151), (177, 131), (200, 150), (181, 166)], closed: true, fill: SketchColor.steel)
                for i in 0..<3 { spatula.line([(CGFloat(166 + i * 6), 148), (CGFloat(176 + i * 6), 139)], color: SketchColor.ink.opacity(0.4), width: 1.2) }
            }
        }
        steam(time: time, x: 126, y: 116)
        for index in 0..<5 {
            let phase = (time * 0.9 + Double(index) * 0.2).truncatingRemainder(dividingBy: 1)
            let x = CGFloat(84 + index * 35)
            oval(x, CGFloat(144 - phase * 8), 2.5, 2.5, fill: SketchColor.ochre.opacity(1 - phase), stroke: 0)
        }
    }

    private mutating func pot(time: TimeInterval) {
        oval(86, 191, 188, 19, fill: SketchColor.shadow, stroke: 0)
        shape(Path(roundedRect: CGRect(x: 60, y: 109, width: 40, height: 31), cornerRadius: 10), fill: SketchColor.steel, width: 1.5)
        shape(Path(roundedRect: CGRect(x: 260, y: 109, width: 40, height: 31), cornerRadius: 10), fill: SketchColor.steel, width: 1.5)
        var pot = Path()
        pot.move(to: CGPoint(x: 90, y: 109))
        pot.addLine(to: CGPoint(x: 270, y: 109))
        pot.addLine(to: CGPoint(x: 262, y: 182))
        pot.addQuadCurve(to: CGPoint(x: 243, y: 198), control: CGPoint(x: 260, y: 198))
        pot.addLine(to: CGPoint(x: 118, y: 198))
        pot.addQuadCurve(to: CGPoint(x: 98, y: 180), control: CGPoint(x: 99, y: 199))
        pot.closeSubpath()
        shape(pot, fill: SketchColor.porcelain)
        oval(90, 86, 180, 46, fill: SketchColor.steel, stroke: 1.3)
        oval(100, 93, 160, 32, fill: SketchColor.water.opacity(0.16), line: SketchColor.ink.opacity(0.4), stroke: 0.8)
        for index in 0..<7 {
            let phase = (time * 0.65 + Double(index) * 0.14).truncatingRemainder(dividingBy: 1)
            let size = CGFloat(3 + phase * 5)
            oval(CGFloat(117 + index * 18), CGFloat(103 + sin(Double(index)) * 6), size, size * 0.6, line: SketchColor.water.opacity(1 - phase), stroke: 1)
        }
        steam(time: time, x: 146, y: 83)
        line([(112, 143), (114, 180)], color: .white.opacity(0.8), width: 3)
        line([(100, 188), (260, 188)], color: SketchColor.ink.opacity(0.2), width: 0.8)
    }

    private mutating func assembly(time: TimeInterval) {
        plate()
        let cycle = time.truncatingRemainder(dividingBy: 7.5)
        var burger = translated(88, 47, scale: 1.03)
        burger.context.opacity = cycle > 6.8 ? 1 - ease((cycle - 6.8) / 0.7) : 1
        burger.burger(assemblyTime: cycle)
    }

    private mutating func lemonGesture(time: TimeInterval) {
        board()
        var lemon = translated(111, 131, scale: 1.55, angle: -13)
        lemon.lemonSlice()
        let motion = CGFloat(sin(time * 2)) * 9
        var tool = translated(195 + motion, 81 + motion, angle: 31)
        tool.line([(0, 0), (23, 0), (24, 93), (-1, 93)], closed: true, fill: SketchColor.steel)
        tool.line([(4, -1), (5, -30), (17, -30), (18, -1)], closed: true, fill: SketchColor.meat)
        for row in 0..<7 {
            tool.line([(6, CGFloat(10 + row * 11)), (16, CGFloat(10 + row * 11))], color: SketchColor.ink.opacity(0.6), width: 0.7)
        }
        for index in 0..<6 {
            let x = CGFloat(211 + index * 7)
            line([(x, CGFloat(180 + index % 3 * 4)), (x + 3, CGFloat(176 + index % 3 * 4))], color: SketchColor.ochre, width: 1.6)
        }
    }
}
