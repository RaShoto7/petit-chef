import SwiftUI

/// The drawing clock runs only while its step is visible and the app is active.
/// Pauses between gestures are part of the choreography, independent of recipe timers.
struct ToastSketchAnimation: View {
    let stepID: String
    var isPlaying = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var elapsed: TimeInterval = 0
    @State private var runningSince: Date?

    private var running: Bool { isPlaying && scenePhase == .active && !reduceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: ProcessInfo.processInfo.isLowPowerModeEnabled ? 1 / 30 : 1 / 60,
                                paused: !running)) { timeline in
            let time = reduceMotion ? 8.0 : elapsed + (runningSince.map { max(0, timeline.date.timeIntervalSince($0)) } ?? 0)
            Canvas { context, size in
                var drawing = ToastDrawing(context: context, size: size)
                drawing.render(step: stepID, elapsed: time)
            }
            .colorEffect(ShaderLibrary.sketchPaper())
        }
        .onChange(of: running, initial: true) { _, value in
            if value {
                runningSince = .now
            } else if let start = runningSince {
                elapsed += Date.now.timeIntervalSince(start)
                runningSince = nil
            }
        }
        .accessibilityHidden(true)
    }
}

private enum ToastInk {
    static let line = Color(red: 0.25, green: 0.27, blue: 0.23)
    static let pale = Color(red: 0.97, green: 0.95, blue: 0.90)
    static let bread = Color(red: 0.86, green: 0.69, blue: 0.43)
    static let crust = Color(red: 0.64, green: 0.43, blue: 0.25)
    static let tomato = Color(red: 0.78, green: 0.34, blue: 0.25)
    static let redWash = Color(red: 0.93, green: 0.68, blue: 0.52)
    static let leaf = Color(red: 0.40, green: 0.53, blue: 0.33)
    static let oil = Color(red: 0.72, green: 0.62, blue: 0.26)
}

private struct ToastDrawing {
    var context: GraphicsContext

    init(context: GraphicsContext, size: CGSize) {
        self.context = context
        let scale = min(size.width / 380, size.height / 280)
        self.context.translateBy(x: (size.width - 380 * scale) / 2, y: (size.height - 280 * scale) / 2)
        self.context.scaleBy(x: scale, y: scale)
    }

    private init(context: GraphicsContext) { self.context = context }

    private func at(_ x: Double, _ y: Double, scale: Double = 1, angle: Double = 0, opacity: Double = 1) -> ToastDrawing {
        var copy = ToastDrawing(context: context)
        copy.context.translateBy(x: x, y: y)
        copy.context.rotate(by: .degrees(angle))
        copy.context.scaleBy(x: scale, y: scale)
        copy.context.opacity *= opacity
        return copy
    }

    mutating func render(step: String, elapsed: Double) {
        // Each sequence has a readable final pose and a gentle dissolve at the loop seam.
        let duration = step == "build-toast" ? 16.0 : 13.0
        let time = elapsed.truncatingRemainder(dividingBy: duration)
        context.opacity = progress(time, 0, 0.6) * (1 - progress(time, duration - 0.7, duration))
        switch step {
        case "preheat-toast": oven(time, baking: false)
        case "slice-tomatoes": cutting(time)
        case "build-toast": assembling(time)
        case "bake-toast": oven(time, baking: true)
        case "dress-tomatoes": mixing(time)
        default: serving(time)
        }
    }

    private func progress(_ time: Double, _ start: Double, _ end: Double) -> Double {
        let t = min(1, max(0, (time - start) / (end - start)))
        return t * t * (3 - 2 * t)
    }

    private func path(_ points: [CGPoint], closed: Bool = false) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
            if closed { path.closeSubpath() }
        }
    }

    private func stroke(_ shape: Path, color: Color = ToastInk.line, width: Double = 1.1) {
        context.stroke(shape, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func outline(_ shape: Path, fill: Color, width: Double = 1.2, hatch: Bool = false) {
        context.fill(shape, with: .color(fill))
        // A fixed second contour suggests graphite; it never jitters with time.
        var pencil = context
        pencil.translateBy(x: 0.8, y: -0.6)
        pencil.stroke(shape, with: .color(ToastInk.line.opacity(0.18)), lineWidth: 0.45)
        stroke(shape, color: ToastInk.line.opacity(0.82), width: width)
        if hatch { hatching(inside: shape, spacing: 6) }
    }

    private func line(_ points: [CGPoint], color: Color = ToastInk.line, width: Double = 1) {
        stroke(path(points), color: color, width: width)
    }

    private func ellipse(_ rect: CGRect, fill: Color, contour: Bool = true) {
        let shape = Path(ellipseIn: rect)
        if contour { outline(shape, fill: fill, width: 0.9) }
        else { context.fill(shape, with: .color(fill)) }
    }

    private func hatching(inside shape: Path, spacing: Double = 7, color: Color = ToastInk.line.opacity(0.12)) {
        var pencil = context
        pencil.clip(to: shape)
        let box = shape.boundingRect.insetBy(dx: -30, dy: -30)
        var marks = Path()
        for x in stride(from: box.minX - box.height, to: box.maxX, by: spacing) {
            marks.move(to: CGPoint(x: x, y: box.maxY))
            marks.addLine(to: CGPoint(x: x + box.height * 0.7, y: box.minY))
        }
        pencil.stroke(marks, with: .color(color), lineWidth: 0.55)
    }

    private func ground() {
        ellipse(CGRect(x: 40, y: 230, width: 300, height: 18), fill: ToastInk.line.opacity(0.035), contour: false)
        line([CGPoint(x: 28, y: 241), CGPoint(x: 156, y: 243)], color: ToastInk.line.opacity(0.22), width: 0.65)
        line([CGPoint(x: 227, y: 243), CGPoint(x: 351, y: 240)], color: ToastInk.line.opacity(0.17), width: 0.6)
    }

    private func board() {
        let shape = path([CGPoint(x: 25, y: 180), CGPoint(x: 151, y: 103), CGPoint(x: 352, y: 167), CGPoint(x: 226, y: 253)], closed: true)
        outline(shape, fill: ToastInk.pale.opacity(0.85), width: 1)
        line([CGPoint(x: 25, y: 180), CGPoint(x: 25, y: 187), CGPoint(x: 226, y: 261), CGPoint(x: 352, y: 175), CGPoint(x: 352, y: 167)], color: ToastInk.crust.opacity(0.60), width: 1)
        var grain = context
        grain.clip(to: shape)
        for i in 0..<16 {
            let y = 126.0 + Double(i) * 7
            var mark = Path()
            mark.move(to: CGPoint(x: 20, y: y))
            mark.addQuadCurve(to: CGPoint(x: 352, y: y + 88), control: CGPoint(x: 161, y: y + 29 + sin(Double(i)) * 3))
            grain.stroke(mark, with: .color(ToastInk.crust.opacity(i % 3 == 0 ? 0.18 : 0.09)), lineWidth: 0.65)
        }
    }

    private func bread(toasted: Double = 0) {
        let top = Path { p in
            p.move(to: CGPoint(x: -55, y: 0))
            p.addCurve(to: CGPoint(x: -45, y: -29), control1: CGPoint(x: -62, y: -16), control2: CGPoint(x: -61, y: -25))
            p.addCurve(to: CGPoint(x: 41, y: -31), control1: CGPoint(x: -17, y: -45), control2: CGPoint(x: 21, y: -44))
            p.addCurve(to: CGPoint(x: 56, y: -3), control1: CGPoint(x: 64, y: -27), control2: CGPoint(x: 69, y: -12))
            p.addCurve(to: CGPoint(x: -55, y: 0), control1: CGPoint(x: 23, y: 17), control2: CGPoint(x: -33, y: 20))
        }
        outline(top.offsetBy(dx: 0, dy: 11), fill: ToastInk.crust.opacity(0.42 + toasted * 0.30), hatch: true)
        outline(top, fill: ToastInk.bread.opacity(0.5 + toasted * 0.25), width: 1.3)
        let crumb = top.applying(CGAffineTransform(scaleX: 0.88, y: 0.84))
        outline(crumb, fill: ToastInk.pale, width: 0.5)
        var pores = context
        pores.clip(to: crumb)
        for i in 0..<95 {
            let x = sin(Double(i) * 4.137) * 52
            let y = cos(Double(i) * 2.731) * 28 - 8
            let radius = i % 9 == 0 ? 2.1 : 0.7
            let hole = Path(ellipseIn: CGRect(x: x, y: y, width: radius * 1.6, height: radius))
            pores.stroke(hole, with: .color(ToastInk.crust.opacity(0.34)), lineWidth: 0.6)
        }
        if toasted > 0 { hatching(inside: crumb, spacing: 9, color: ToastInk.crust.opacity(toasted * 0.15)) }
    }

    private func leaf() {
        let silhouette = Path { p in
            p.move(to: CGPoint(x: -17, y: 9))
            p.addCurve(to: CGPoint(x: 17, y: -11), control1: CGPoint(x: -23, y: -13), control2: CGPoint(x: 1, y: -23))
            p.addCurve(to: CGPoint(x: -17, y: 9), control1: CGPoint(x: 19, y: 6), control2: CGPoint(x: 3, y: 18))
        }
        outline(silhouette, fill: ToastInk.leaf.opacity(0.64), width: 0.7, hatch: true)
        line([CGPoint(x: -20, y: 12), CGPoint(x: 13, y: -9)], color: ToastInk.line.opacity(0.65), width: 0.7)
        for i in 0..<4 {
            let x = Double(i) * 6 - 12
            line([CGPoint(x: x - 4, y: 1 - Double(i) * 2), CGPoint(x: x, y: 7 - Double(i) * 4), CGPoint(x: x + 8, y: 9 - Double(i) * 3)], color: ToastInk.line.opacity(0.4), width: 0.55)
        }
    }

    private func tomatoSlice() {
        ellipse(CGRect(x: -30, y: -18, width: 60, height: 38), fill: ToastInk.tomato.opacity(0.70))
        ellipse(CGRect(x: -26, y: -15, width: 52, height: 30), fill: ToastInk.redWash)
        for i in 0..<4 {
            let angle = Double(i) * .pi / 2 + .pi / 4
            let center = CGPoint(x: cos(angle) * 14, y: sin(angle) * 8)
            let chamber = Path(ellipseIn: CGRect(x: center.x - 7, y: center.y - 4, width: 14, height: 8))
            context.fill(chamber, with: .color(ToastInk.tomato.opacity(0.5)))
            for j in 0..<3 {
                ellipse(CGRect(x: center.x + Double(j - 1) * 3, y: center.y - 1, width: 1.6, height: 2.2), fill: ToastInk.pale, contour: false)
            }
        }
        stroke(Path(ellipseIn: CGRect(x: -24, y: -14, width: 49, height: 27)), color: ToastInk.tomato.opacity(0.8), width: 0.55)
    }

    private func dice(_ seed: Int) {
        let skew = Double(seed % 3) * 0.7
        let shape = path([CGPoint(x: -6, y: -5), CGPoint(x: 3, y: -7), CGPoint(x: 7, y: -2), CGPoint(x: 5, y: 5 + skew), CGPoint(x: -5, y: 5)], closed: true)
        outline(shape, fill: ToastInk.tomato.opacity(0.72), width: 0.7)
        line([CGPoint(x: -4, y: -3), CGPoint(x: 2, y: -4), CGPoint(x: 4, y: -1)], color: ToastInk.pale.opacity(0.9), width: 1.2)
        line([CGPoint(x: -4, y: 4), CGPoint(x: 3, y: 4)], color: ToastInk.tomato, width: 0.8)
    }

    private func mozzarella() {
        let slice = Path { p in
            p.move(to: CGPoint(x: -24, y: 2))
            p.addCurve(to: CGPoint(x: -15, y: -13), control1: CGPoint(x: -30, y: -8), control2: CGPoint(x: -23, y: -15))
            p.addCurve(to: CGPoint(x: 22, y: -10), control1: CGPoint(x: -1, y: -18), control2: CGPoint(x: 21, y: -20))
            p.addCurve(to: CGPoint(x: 15, y: 10), control1: CGPoint(x: 33, y: 2), control2: CGPoint(x: 25, y: 9))
            p.addCurve(to: CGPoint(x: -24, y: 2), control1: CGPoint(x: -2, y: 14), control2: CGPoint(x: -19, y: 13))
        }
        outline(slice.offsetBy(dx: 0, dy: 3), fill: ToastInk.pale, width: 0.65)
        outline(slice, fill: .white, width: 0.75)
        stroke(slice.applying(CGAffineTransform(scaleX: 0.8, y: 0.70)), color: ToastInk.line.opacity(0.13), width: 0.5)
    }

    private func garlic() {
        let shape = Path { p in
            p.move(to: CGPoint(x: -12, y: 8))
            p.addCurve(to: CGPoint(x: 7, y: -15), control1: CGPoint(x: -20, y: -11), control2: CGPoint(x: -3, y: -12))
            p.addCurve(to: CGPoint(x: 12, y: 8), control1: CGPoint(x: 2, y: -3), control2: CGPoint(x: 22, y: 2))
            p.addQuadCurve(to: CGPoint(x: -12, y: 8), control: CGPoint(x: -2, y: 20))
        }
        outline(shape, fill: ToastInk.pale, width: 0.8)
        line([CGPoint(x: 5, y: -11), CGPoint(x: -2, y: 9)], color: ToastInk.crust.opacity(0.45), width: 0.7)
    }

    private func knife() {
        let blade = Path { p in
            p.move(to: CGPoint(x: -62, y: 7))
            p.addQuadCurve(to: CGPoint(x: 48, y: 9), control: CGPoint(x: 3, y: 14))
            p.addLine(to: CGPoint(x: 48, y: -14))
            p.addLine(to: CGPoint(x: -37, y: -19))
            p.addQuadCurve(to: CGPoint(x: -62, y: 7), control: CGPoint(x: -52, y: -9))
        }
        outline(blade, fill: Color(white: 0.96), width: 1.2)
        hatching(inside: blade, spacing: 5, color: ToastInk.line.opacity(0.09))
        line([CGPoint(x: -52, y: 5), CGPoint(x: 46, y: 6)], color: ToastInk.line.opacity(0.5), width: 0.55)
        let handle = Path(roundedRect: CGRect(x: 48, y: -15, width: 57, height: 21), cornerRadius: 5)
        outline(handle, fill: ToastInk.line.opacity(0.86), width: 1)
        for x in [59.0, 84.0] { ellipse(CGRect(x: x, y: -8, width: 3.4, height: 3.4), fill: ToastInk.pale, contour: false) }
    }

    private mutating func cutting(_ time: Double) {
        ground(); board()
        at(109, 117, scale: 0.93).tomatoSlice()
        at(84, 99, scale: 0.65, angle: -28).leaf()
        at(282, 197, scale: 0.8, angle: 10).mozzarella()
        at(285, 222, scale: 0.67, angle: -20).garlic()
        // Four complete rocking cuts: lift, forward travel, contact, then release.
        let cutTime = max(0, min(7.6, time - 0.8))
        let cut = min(3, Int(cutTime / 1.9))
        let phase = cutTime - Double(cut) * 1.9
        let down = progress(phase, 0.55, 1.15)
        let lift = progress(phase, 1.35, 1.85)
        let contact = down * (1 - lift)
        let advance = Double(cut) * 8 + progress(phase, 1.45, 1.9) * 8
        at(173, 171, angle: 15).tomatoSlice()
        for i in 0..<16 {
            let appeared = progress(time, 1.95 + Double(i / 4) * 1.9, 2.35 + Double(i / 4) * 1.9)
            let x = 117 + Double(i % 4) * 13 - appeared * 11
            let y = 191 + Double(i / 4) * 10
            at(x, y, angle: Double(i * 37), opacity: appeared).dice(i)
        }
        let rest = progress(time, 8.5, 9.4)
        at(194 + advance + rest * 23, 115 + contact * 47 + rest * 15,
           angle: -27 + contact * 9 + rest * 20).knife()
    }

    private mutating func assembling(_ time: Double) {
        ground(); board()
        for (i, point) in [CGPoint(x: 126, y: 166), CGPoint(x: 251, y: 194)].enumerated() {
            at(point.x, point.y, scale: 0.95, angle: 12).bread()
            let rub = min(1, max(0, (time - 0.5) / 3.2))
            if time < 4.5 {
                let fade = (1 - progress(time, 3.4, 4.3)) * progress(time, 0, 0.5)
                at(point.x + sin(rub * .pi * 5) * 29, point.y - 15,
                   scale: 0.85, angle: sin(rub * .pi * 5) * 12, opacity: fade).garlic()
            }
            let oil = progress(time, 4, 6)
            var trail = Path()
            trail.move(to: CGPoint(x: point.x - 33, y: point.y - 16))
            trail.addCurve(to: CGPoint(x: point.x + 29, y: point.y - 3), control1: CGPoint(x: point.x - 8, y: point.y - 36), control2: CGPoint(x: point.x + 3, y: point.y + 10))
            stroke(trail.trimmedPath(from: 0, to: oil), color: ToastInk.oil.opacity(0.64), width: 2)
            for j in 0..<3 {
                let settle = progress(time, 6.3 + Double(i) * 1.2 + Double(j) * 0.7, 7.4 + Double(i) * 1.2 + Double(j) * 0.7)
                at(point.x + Double(j - 1) * 25 + (1 - settle) * 18,
                   point.y - 12 - (1 - settle) * 80, scale: 0.85,
                   angle: 9 + (1 - settle) * 24, opacity: settle).mozzarella()
            }
        }
        if time >= 3.8 && time < 6.8 {
            let pour = progress(time, 3.8, 4.4) * (1 - progress(time, 6, 6.8))
            let tilt = -115 * pour
            var bottle = at(302, 65, angle: tilt, opacity: pour)
            bottle.oilBottle()
            let targetX = 120 + progress(time, 4.4, 5.8) * 130
            var stream = Path()
            stream.move(to: CGPoint(x: 302 + sin(tilt * .pi / 180) * 45, y: 65 - cos(tilt * .pi / 180) * 45))
            stream.addQuadCurve(to: CGPoint(x: targetX, y: 162 + (targetX - 120) * 0.2), control: CGPoint(x: 248, y: 93))
            stroke(stream, color: ToastInk.oil.opacity(pour * 0.55), width: 1.2)
        }
    }

    private mutating func oilBottle() {
        let shape = path([CGPoint(x: -10, y: 20), CGPoint(x: -10, y: -18), CGPoint(x: -5, y: -26), CGPoint(x: -5, y: -45), CGPoint(x: 5, y: -45), CGPoint(x: 5, y: -26), CGPoint(x: 10, y: -18), CGPoint(x: 10, y: 20)], closed: true)
        outline(shape, fill: ToastInk.oil.opacity(0.22), width: 1)
        line([CGPoint(x: -6, y: 15), CGPoint(x: -6, y: -14)], color: .white, width: 2)
        line([CGPoint(x: -4, y: -38), CGPoint(x: 4, y: -38)], color: ToastInk.line.opacity(0.5), width: 0.7)
    }

    private mutating func oven(_ time: Double, baking: Bool) {
        ground()
        // Fine architectural contours, etched glass and a visible interior rack.
        let top = path([CGPoint(x: 62, y: 73), CGPoint(x: 122, y: 42), CGPoint(x: 314, y: 71), CGPoint(x: 260, y: 106)], closed: true)
        outline(top, fill: ToastInk.pale.opacity(0.42), hatch: true)
        let side = path([CGPoint(x: 260, y: 106), CGPoint(x: 314, y: 71), CGPoint(x: 314, y: 200), CGPoint(x: 260, y: 238)], closed: true)
        outline(side, fill: ToastInk.pale.opacity(0.75), hatch: true)
        let front = path([CGPoint(x: 62, y: 73), CGPoint(x: 260, y: 106), CGPoint(x: 260, y: 238), CGPoint(x: 62, y: 206)], closed: true)
        outline(front, fill: .white, width: 1.3)
        line([CGPoint(x: 63, y: 105), CGPoint(x: 259, y: 138)], width: 0.7)
        let dial = at(227, 119, scale: 0.9)
        dial.ellipse(CGRect(x: -9, y: -9, width: 18, height: 18), fill: ToastInk.pale)
        let angle = -1.7 + progress(time, 0.8, 2.2) * 2.2
        dial.line([.zero, CGPoint(x: cos(angle) * 6, y: sin(angle) * 6)], width: 1.3)
        ellipse(CGRect(x: 198, y: 111, width: 3.5, height: 3.5), fill: ToastInk.crust.opacity(progress(time, 1.5, 2.5)), contour: false)
        let window = path([CGPoint(x: 79, y: 123), CGPoint(x: 242, y: 151), CGPoint(x: 242, y: 213), CGPoint(x: 79, y: 187)], closed: true)
        outline(window, fill: ToastInk.pale.opacity(0.9), width: 1)
        for i in 0..<7 {
            line([CGPoint(x: 85 + Double(i) * 21, y: 184 + Double(i) * 3.4), CGPoint(x: 103 + Double(i) * 21, y: 174 + Double(i) * 3.4)], color: ToastInk.line.opacity(0.4), width: 0.6)
        }
        if baking {
            let insert = progress(time, 1.0, 3.6)
            let tray = at((1 - insert) * -18, (1 - insert) * 32)
            let trayShape = path([CGPoint(x: 83, y: 172), CGPoint(x: 110, y: 156), CGPoint(x: 239, y: 178), CGPoint(x: 214, y: 197)], closed: true)
            tray.outline(trayShape, fill: .white, width: 0.8)
            let browned = progress(time, 4.0, 8.5)
            for x in [129.0, 195.0] {
                tray.at(x, 168 + (x - 129) * 0.16, scale: 0.45, angle: 9).bread(toasted: browned)
                tray.at(x, 163 + (x - 129) * 0.16, scale: 0.58, angle: 9).mozzarella()
                for j in 0..<4 {
                    tray.ellipse(CGRect(x: x + Double(j - 2) * 5, y: 164 + (x - 129) * 0.16 + sin(Double(j)) * 4, width: 2.5, height: 1.4), fill: ToastInk.crust.opacity(browned * 0.45), contour: false)
                }
            }
        }
        // The upper edge rotates around the lower hinge after the tray settles.
        let close = baking ? progress(time, 3.8, 5.2) : 1
        let leftTop = CGPoint(x: 79 - (1 - close) * 34, y: 123 + (1 - close) * 95)
        let rightTop = CGPoint(x: 242 - (1 - close) * 34, y: 151 + (1 - close) * 95)
        let door = path([leftTop, rightTop, CGPoint(x: 242, y: 213), CGPoint(x: 79, y: 187)], closed: true)
        outline(door, fill: ToastInk.pale.opacity(0.15 + (1 - close) * 0.7), width: 0.8)
        line([CGPoint(x: leftTop.x + 12, y: leftTop.y + 3), CGPoint(x: rightTop.x - 12, y: rightTop.y - 1)], width: 2)
        if close > 0.8 {
            var reflection = context
            reflection.opacity = progress(close, 0.8, 1)
            reflection.clip(to: window)
            reflection.stroke(path([CGPoint(x: 138, y: 124), CGPoint(x: 105, y: 200)]), with: .color(.white.opacity(0.8)), lineWidth: 10)
            reflection.stroke(path([CGPoint(x: 150, y: 128), CGPoint(x: 117, y: 204)]), with: .color(.white.opacity(0.8)), lineWidth: 2)
        }
        if time > 4 {
            for i in 0..<3 {
                let wave = sin(time * 0.65 + Double(i)) * 3
                var heat = Path()
                let x = 162 + Double(i) * 24
                heat.move(to: CGPoint(x: x, y: 57))
                heat.addCurve(to: CGPoint(x: x + wave, y: 30), control1: CGPoint(x: x + 7, y: 46), control2: CGPoint(x: x - 7, y: 40))
                stroke(heat, color: ToastInk.crust.opacity(0.22), width: 0.7)
            }
        }
    }

    private mutating func mixing(_ time: Double) {
        ground()
        let bowl = Path { p in
            p.move(to: CGPoint(x: 86, y: 151))
            p.addCurve(to: CGPoint(x: 283, y: 151), control1: CGPoint(x: 84, y: 259), control2: CGPoint(x: 279, y: 264))
        }
        outline(bowl, fill: ToastInk.pale.opacity(0.62), width: 1.3, hatch: true)
        ellipse(CGRect(x: 85, y: 108, width: 200, height: 91), fill: .white)
        let spin = min(7.5, max(0, time - 0.8)) * 0.82
        for i in 0..<24 {
            let angle = Double(i) * 2.399 + spin
            let radius = 20.0 + Double(i % 5) * 11
            at(183 + cos(angle) * radius, 151 + sin(angle) * radius * 0.40,
               scale: 0.9, angle: angle * 32).dice(i)
        }
        for i in 0..<4 {
            let a = Double(i) * 1.7 + spin * 0.4
            at(180 + cos(a) * 45, 146 + sin(a) * 17, scale: 0.48, angle: a * 33).leaf()
        }
        let spoonX = 182 + cos(spin) * 46
        let spoonY = 147 + sin(spin) * 23
        let rest = progress(time, 8.3, 9.4)
        let spoon = at(spoonX + rest * 25, spoonY - rest * 13, angle: -36 - sin(spin) * 9)
        spoon.outline(Path(roundedRect: CGRect(x: -5, y: -115, width: 10, height: 113), cornerRadius: 5), fill: ToastInk.bread.opacity(0.50), width: 0.9)
        spoon.ellipse(CGRect(x: -17, y: -22, width: 34, height: 45), fill: ToastInk.bread.opacity(0.55))
        spoon.line([CGPoint(x: 0, y: -99), CGPoint(x: 0, y: -26)], color: ToastInk.crust.opacity(0.4), width: 0.7)
        var frontRim = Path()
        frontRim.move(to: CGPoint(x: 86, y: 151))
        frontRim.addCurve(to: CGPoint(x: 284, y: 151), control1: CGPoint(x: 96, y: 214), control2: CGPoint(x: 282, y: 218))
        stroke(frontRim, color: ToastInk.line.opacity(0.55), width: 1)
    }

    private mutating func serving(_ time: Double) {
        ground()
        ellipse(CGRect(x: 36, y: 121, width: 310, height: 124), fill: ToastInk.pale.opacity(0.36))
        stroke(Path(ellipseIn: CGRect(x: 50, y: 130, width: 282, height: 102)), color: ToastInk.line.opacity(0.28), width: 0.65)
        for (side, point) in [CGPoint(x: 119, y: 171), CGPoint(x: 257, y: 181)].enumerated() {
            at(point.x, point.y, angle: -12 + Double(side) * 16).bread(toasted: 1)
            for j in 0..<3 { at(point.x + Double(j - 1) * 26, point.y - 11, scale: 0.9).mozzarella() }
            for i in 0..<11 {
                let land = progress(time, 0.6 + Double(i) * 0.14 + Double(side) * 1.6, 1.4 + Double(i) * 0.14 + Double(side) * 1.6)
                let x = point.x + Double(i % 4 - 2) * 20 + 9 + sin(Double(i) * 2.4) * 4
                let y = point.y + Double(i / 4 - 1) * 11 - 10
                at(x + (1 - land) * 19, y - (1 - land) * 64,
                   angle: Double(i * 31) + (1 - land) * 60, opacity: land).dice(i)
            }
            for i in 0..<2 {
                let land = progress(time, 4.8 + Double(side) * 0.7 + Double(i) * 0.5, 6.0 + Double(side) * 0.7 + Double(i) * 0.5)
                at(point.x + Double(i) * 37 - 22 + sin((1 - land) * .pi) * 20,
                   point.y - 21 - (1 - land) * 67, scale: 0.76,
                   angle: -20 + Double(i) * 70 + (1 - land) * 90, opacity: land).leaf()
            }
        }
    }
}
