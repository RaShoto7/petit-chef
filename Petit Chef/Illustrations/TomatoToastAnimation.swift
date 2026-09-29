import SwiftUI

/// A six-second demonstration, then a still result. Playback has no cooking side effects.
struct TomatoToastAnimation: View {
    let gesture: TomatoToastGesture
    let temperatureUnit: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var elapsed: TimeInterval = 0
    @State private var origin = Date()
    @State private var playing = true

    private var running: Bool { playing && !reduceMotion && scenePhase == .active }
    private func time(at date: Date) -> Double {
        min(6, elapsed + (running ? max(0, date.timeIntervalSince(origin)) : 0))
    }

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !running)) { timeline in
                Canvas { context, size in
                    var drawing = ToastGestureDrawing(context: context, size: size)
                    drawing.draw(gesture, time: reduceMotion ? 6 : time(at: timeline.date),
                                 temperature: CookingText.formatted("180 °C", unit: temperatureUnit))
                }
                .accessibilityHidden(true)
            }
            .frame(height: 210)
            HStack {
                Text(reduceMotion ? "Le geste en image" : "Le geste en mouvement")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !reduceMotion {
                    Button {
                        if playing {
                            elapsed = time(at: .now)
                            playing = false
                        } else {
                            if elapsed >= 6 { elapsed = 0 }
                            origin = .now
                            playing = true
                        }
                    } label: {
                        Image(systemName: playing ? "pause.fill" : "play.fill").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(playing ? "Mettre le geste en pause" : "Lire le geste")
                    .accessibilityIdentifier("toast.animation.play")
                    Button {
                        elapsed = 0; origin = .now; playing = true
                    } label: {
                        Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Revoir le geste")
                    .accessibilityIdentifier("cooking.replay")
                }
            }
            .font(.subheadline).tint(DesignSystem.Colors.accent)
            .padding(.horizontal, 14)
        }
        .background(Color(red: 0.985, green: 0.975, blue: 0.95), in: RoundedRectangle(cornerRadius: 22))
        .task(id: PlaybackKey(running: running, origin: origin)) {
            guard running else { return }
            do { try await Task.sleep(for: .seconds(max(0, 6 - elapsed))) }
            catch { return }
            elapsed = 6; playing = false
        }
        .onChange(of: scenePhase) { old, new in
            if old == .active && playing { elapsed = min(6, elapsed + Date().timeIntervalSince(origin)) }
            if new == .active { origin = .now }
        }
        .onChange(of: reduceMotion) { _, _ in
            elapsed = 0; origin = .now
        }
    }

    private struct PlaybackKey: Equatable {
        let running: Bool
        let origin: Date
    }
}

/// Geometry is local to this recipe, so its ingredients never appear in other dishes.
private struct ToastGestureDrawing {
    var context: GraphicsContext
    private let ink = Color(red: 0.31, green: 0.32, blue: 0.26)
    private let crust = Color(red: 0.74, green: 0.49, blue: 0.29)
    private let crumb = Color(red: 0.97, green: 0.87, blue: 0.66)
    private let red = Color(red: 0.81, green: 0.30, blue: 0.21)
    private let flesh = Color(red: 0.96, green: 0.52, blue: 0.36)
    private let green = Color(red: 0.33, green: 0.49, blue: 0.29)
    private let gold = Color(red: 0.77, green: 0.63, blue: 0.23)
    private let steel = Color(red: 0.80, green: 0.85, blue: 0.84)

    init(context: GraphicsContext, size: CGSize) {
        self.context = context
        let scale = min(size.width / 360, size.height / 240)
        self.context.translateBy(x: (size.width - 360 * scale) / 2, y: (size.height - 240 * scale) / 2)
        self.context.scaleBy(x: scale, y: scale)
    }
    private func ease(_ x: Double) -> Double { let v = min(1, max(0, x)); return v * v * (3 - 2 * v) }
    private mutating func path(_ points: [CGPoint], fill: Color? = nil, stroke: Color? = nil, width: CGFloat = 1.5, closed: Bool = false) {
        guard let first = points.first else { return }
        var p = Path(); p.move(to: first)
        for point in points.dropFirst() { p.addLine(to: point) }
        if closed { p.closeSubpath() }
        paint(p, fill: fill, stroke: stroke, width: width)
    }
    private mutating func paint(_ p: Path, fill: Color? = nil, stroke: Color? = nil, width: CGFloat = 1.5) {
        if let fill { context.fill(p, with: .color(fill)) }
        if width > 0 { context.stroke(p, with: .color(stroke ?? ink), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)) }
    }
    private mutating func oval(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ fill: Color, width: CGFloat = 1) {
        paint(Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)), fill: fill, width: width)
    }
    private mutating func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double, _ fill: Color, width: CGFloat = 1) {
        paint(Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r), fill: fill, width: width)
    }
    private mutating func line(_ x: Double, _ y: Double, _ x2: Double, _ y2: Double, _ color: Color? = nil, width: CGFloat = 1.5) {
        path([CGPoint(x: x, y: y), CGPoint(x: x2, y: y2)], stroke: color, width: width)
    }
    private mutating func board() {
        oval(55, 197, 252, 17, ink.opacity(0.06), width: 0)
        rect(35, 87, 290, 117, 22, crumb.opacity(0.45))
        line(52, 190, 307, 190, crust.opacity(0.25))
        line(54, 100, 113, 100, crust.opacity(0.18))
        line(273, 111, 310, 111, crust.opacity(0.18))
    }
    private mutating func bread(x: Double = 97, y: Double = 100, scale: Double = 1, toasted: Double = 0) {
        let saved = context
        context.translateBy(x: x, y: y); context.scaleBy(x: scale, y: scale)
        var p = Path()
        p.move(to: CGPoint(x: 3, y: 25))
        p.addCurve(to: CGPoint(x: 145, y: 5), control1: CGPoint(x: 20, y: -1), control2: CGPoint(x: 111, y: -22))
        p.addCurve(to: CGPoint(x: 155, y: 83), control1: CGPoint(x: 170, y: 22), control2: CGPoint(x: 175, y: 63))
        p.addCurve(to: CGPoint(x: 18, y: 102), control1: CGPoint(x: 128, y: 109), control2: CGPoint(x: 54, y: 123))
        p.addCurve(to: CGPoint(x: 3, y: 25), control1: CGPoint(x: -1, y: 90), control2: CGPoint(x: -7, y: 47))
        p.closeSubpath()
        paint(p, fill: crust)
        context.translateBy(x: 8, y: 7); context.scaleBy(x: 0.9, y: 0.86)
        paint(p, fill: crumb, stroke: crust.opacity(0.5), width: 1)
        paint(p, fill: gold.opacity(toasted * 0.17), width: 0)
        for i in 0..<13 {
            oval(Double(17 + (i * 31) % 128), Double(17 + (i * 19) % 70), Double(3 + i % 4), Double(2 + i % 3), crust.opacity(0.3), width: 0)
        }
        context = saved
    }
    private mutating func cheese(_ x: Double, _ y: Double, melt: Double = 0, scale: Double = 1) {
        let saved = context
        context.translateBy(x: x - melt * 5, y: y - melt * 2)
        context.scaleBy(x: scale, y: scale)
        var p = Path()
        p.move(to: .init(x: 2, y: 13))
        p.addCurve(to: .init(x: 25, y: -melt * 4), control1: .init(x: -2, y: 1), control2: .init(x: 11, y: -2))
        p.addCurve(to: .init(x: 47 + melt * 7, y: 16), control1: .init(x: 41, y: -1), control2: .init(x: 51 + melt * 8, y: 2))
        p.addCurve(to: .init(x: 27, y: 32 + melt * 5), control1: .init(x: 53, y: 31), control2: .init(x: 37, y: 28 + melt * 10))
        p.addCurve(to: .init(x: 2, y: 13), control1: .init(x: 9, y: 30), control2: .init(x: -5 - melt * 3, y: 34))
        paint(p, fill: Color(red: 1, green: 0.99, blue: 0.94), stroke: ink.opacity(0.55), width: 0.9)
        line(10, 11, 29, 8, .white, width: 2)
        if melt > 0 {
            for i in 0..<4 {
                oval(Double(9 + (i * 11) % 31), Double(9 + (i * 7) % 16), Double(3 + i % 2), 2, gold.opacity(melt * 0.5), width: 0)
            }
        }
        context = saved
    }

    private mutating func cubes(_ x: Double, _ y: Double, scale: Double = 1) {
        let saved = context; context.translateBy(x: x, y: y); context.scaleBy(x: scale, y: scale)
        path([.init(x: 0, y: 3), .init(x: 15, y: 0), .init(x: 19, y: 13), .init(x: 4, y: 18)], fill: flesh, stroke: red, closed: true)
        line(5, 6, 11, 5, crumb, width: 2)
        context = saved
    }
    private mutating func leaf(_ x: Double, _ y: Double, angle: Double = 0, scale: Double = 1) {
        let saved = context; context.translateBy(x: x, y: y); context.rotate(by: .degrees(angle)); context.scaleBy(x: scale, y: scale)
        var p = Path(); p.move(to: .zero)
        p.addQuadCurve(to: .init(x: 27, y: -13), control: .init(x: 1, y: -29))
        p.addQuadCurve(to: .zero, control: .init(x: 27, y: 7))
        paint(p, fill: green, stroke: green, width: 1)
        line(1, -1, 22, -13, crumb.opacity(0.6), width: 1)
        context = saved
    }
    private mutating func knife(x: Double, y: Double, angle: Double = 0) {
        let saved = context; context.translateBy(x: x, y: y); context.rotate(by: .degrees(angle))
        path([.init(x: 0, y: -65), .init(x: 24, y: -65), .init(x: 23, y: 7), .init(x: 0, y: 30)], fill: steel, closed: true)
        line(3, -59, 3, 20, .white, width: 2)
        rect(1, -107, 20, 43, 5, ink)
        oval(8, -98, 4, 4, steel, width: 0); oval(8, -77, 4, 4, steel, width: 0)
        context = saved
    }
    private mutating func garlic(_ x: Double, _ y: Double, split: Double = 0) {
        for i in 0..<2 {
            let dx = Double(i) * (19 + split * 12)
            oval(x + dx, y, 20, 37, crumb.opacity(0.75))
            line(x + dx + 8, y + 7, x + dx + 11, y + 30, .white, width: 2)
        }
    }
    private mutating func drizzle(x: Double, y: Double, time: Double) {
        let pour = ease(time / 0.7) * (1 - ease((time - 2.0) / 0.6))
        let saved = context
        context.translateBy(x: x, y: y); context.rotate(by: .degrees(-35 * pour))
        rect(-12, -47, 28, 49, 7, green.opacity(0.65))
        rect(-5, -59, 14, 16, 3, gold)
        rect(-8, -27, 20, 15, 2, crumb, width: 0)
        context = saved
        if pour > 0.05 {
            var p = Path(); p.move(to: .init(x: x - 28 * pour, y: y - 47))
            p.addQuadCurve(to: .init(x: x - 55, y: 140), control: .init(x: x - 70, y: y + 10))
            paint(p, stroke: gold.opacity(pour), width: 3)
        }
    }

    mutating func draw(_ gesture: TomatoToastGesture, time t: Double, temperature: String) {
        switch gesture {
        case .preheat: oven(time: t, temperature: temperature, preheat: true)
        case .bread:
            rect(38, 98, 284, 104, 12, steel)
            rect(48, 106, 264, 86, 4, .white.opacity(0.8), width: 0)
            for i in 0..<3 {
                let p = ease((t - Double(i) * 0.75) / 1.1)
                let saved = context; context.opacity = p
                bread(x: Double(57 + i * 84), y: 119 - 56 * (1 - p), scale: 0.48)
                context = saved
            }
        case .dice: dice(time: t)
        case .mozzarella: sliceMozzarella(time: t)
        case .garlic:
            board()
            let split = ease((t - 1.8) / 1)
            garlic(158 - split * 8, 135, split: split)
            if t < 3.5 { knife(x: 175, y: 144 - 35 * (1 - ease(t / 1.8)) - 90 * ease((t - 2.5) / 1)) }
        case .rub:
            board(); bread()
            let x = 147 + sin(min(t, 4.5) * 4) * 29
            garlic(t < 4.5 ? x : 283, t < 4.5 ? 119 : 149, split: 0.3)
            if t < 4.5 { line(x - 2, 171, x + 22, 169, gold.opacity(0.5), width: 2) }
        case .oil:
            board(); bread()
            let amount = ease(t / 3)
            for i in 0..<4 { line(128, Double(123 + i * 15), 128 + amount * 88, Double(118 + i * 15), gold.opacity(0.6), width: 2.5) }
            if t < 3.2 { drizzle(x: 239, y: 90, time: t) }
        case .layer:
            board(); bread()
            for i in 0..<3 {
                let p = ease((t - Double(i) * 1.0) / 0.9)
                let saved = context; context.opacity = p
                cheese(Double(116 + i * 35), Double(127 + (i % 2) * 26) - 65 * (1 - p))
                context = saved
            }
        case .bake: oven(time: t, temperature: temperature, preheat: false)
        case .check:
            board(); bread(toasted: ease(t / 3))
            for i in 0..<3 { cheese(Double(116 + i * 35), Double(127 + (i % 2) * 26), melt: ease(t / 3)) }
        case .season: bowl(time: t, mixing: false)
        case .mix: bowl(time: t, mixing: true)
        case .top, .finish:
            oval(44, 106, 272, 105, .white.opacity(0.9))
            oval(62, 118, 235, 77, crumb.opacity(0.12))
            bread(toasted: 1)
            for i in 0..<3 { cheese(Double(116 + i * 35), Double(127 + (i % 2) * 26), melt: 1) }
            for i in 0..<8 {
                let p = gesture == .finish ? 1 : ease((t - Double(i) * 0.35) / 0.75)
                let saved = context; context.opacity = p
                cubes(Double(121 + (i % 4) * 28), Double(132 + (i / 4) * 31) - 55 * (1 - p), scale: 0.85)
                context = saved
            }
            if gesture == .finish {
                for i in 0..<3 {
                    let p = ease((t - Double(i) * 0.7) / 1)
                    let saved = context; context.opacity = p
                    leaf(Double(132 + i * 38), Double(150 + (i % 2) * 23) - 58 * (1 - p), angle: Double(i * 50 - 25), scale: 0.8)
                    context = saved
                }
            }
        }
    }

    private mutating func dice(time t: Double) {
        board()
        // The longitudinal cuts precede the cross-cuts. Separated cubes stay on the board.
        let columns = min(3, Int(max(0, t - 0.4) / 0.65))
        let rows = min(3, Int(max(0, t - 2.7) / 0.65))
        for row in 0..<3 {
            for column in 0..<4 {
                let x = 111.0 + Double(column) * 28 + Double(min(column, columns)) * 3
                let y = 117.0 + Double(row) * 24 + Double(min(row, rows)) * 5
                rect(x, y, 28, 24, 1, flesh, width: 0)
                // Cut edges appear only after the blade passes; uncut pieces still touch.
                if column < columns || rows > row {
                    line(x + 1, y + 23, x + 26, y + 23, red, width: 1.4)
                    line(x + 26, y + 2, x + 27, y + 21, red, width: 1.4)
                }
                oval(x + 6, y + 5, 13, 12, red.opacity(0.3), width: 0)
                line(x + 9, y + 8, x + 12, y + 6, crumb, width: 1.6)
                line(x + 16, y + 11, x + 15, y + 15, crumb, width: 1.4)
            }
        }
        if t < 5 {
            let phase = t.truncatingRemainder(dividingBy: 0.65) / 0.65
            let lift = 28 * pow(cos(phase * .pi), 2)
            if t < 2.7 { knife(x: Double(136 + columns * 30), y: 159 - lift) }
            else { knife(x: 139, y: Double(129 + rows * 25) - lift, angle: -90) }
        }
        if t >= 4.8 {
            line(117, 213, 144, 213, green)
            line(117, 209, 117, 217, green); line(144, 209, 144, 217, green)
            context.draw(Text("1 cm").font(.system(size: 13, weight: .medium)).foregroundColor(green), at: .init(x: 179, y: 213))
        }
    }

    private mutating func sliceMozzarella(time t: Double) {
        board()
        rect(87, 105, 173, 86, 7, .white.opacity(0.8), width: 0)
        for i in 0..<5 {
            let p = ease((t - 1.8 - Double(i) * 0.5) / 0.5)
            let x = 122 + Double(i) * (14 + p * 9)
            oval(x, 122 + p * Double(i) * 2, 30, 49, .white)
        }
        if t < 1.8 {
            let p = sin(min(1, t / 1.8) * .pi)
            rect(116, 102 + p * 12, 95, 45, 8, Color(white: 0.95))
            for i in 0..<4 { line(Double(126 + i * 22), 109 + p * 12, Double(126 + i * 22), 140 + p * 12, steel.opacity(0.65)) }
        } else if t < 4.8 {
            let cut = min(4, Int((t - 1.8) / 0.5))
            knife(x: Double(142 + cut * 21), y: 145 - 24 * abs(sin((t - 1.8) * .pi * 2)))
        }
    }

    private mutating func oven(time t: Double, temperature: String, preheat: Bool) {
        oval(60, 215, 240, 12, ink.opacity(0.07), width: 0)
        rect(57, 29, 246, 184, 15, Color(white: 0.95))
        rect(70, 41, 220, 39, 7, crumb.opacity(0.35))
        oval(81, 50, 20, 20, steel)
        let angle = ease(t / 2) * .pi * 1.2 - .pi / 2
        line(91, 60, 91 + cos(angle) * 7, 60 + sin(angle) * 7, ink, width: 2)
        context.draw(Text(temperature).font(.system(size: 18, weight: .medium, design: .monospaced)).foregroundColor(ink), at: .init(x: 191, y: 61))
        let warm = ease(t / 3)
        oval(269, 57, 7, 7, gold.opacity(0.3 + warm * 0.7), width: 0)
        rect(74, 90, 212, 106, 6, ink.opacity(0.84))
        rect(82, 99, 196, 90, 5, crust.opacity(0.08 + warm * 0.15), width: 0)
        line(86, 155, 275, 155, steel, width: 2)
        if !preheat {
            let p = ease(t / 2.7)
            let saved = context
            context.translateBy(x: 0, y: (1 - p) * 49)
            rect(89, 146, 179, 10, 3, steel)
            for i in 0..<3 {
                bread(x: Double(98 + i * 55), y: 116, scale: 0.28, toasted: ease((t - 3) / 2))
                cheese(Double(109 + i * 55), 127, melt: ease((t - 3) / 2), scale: 0.55)
            }
            context = saved
        }
        let closed = preheat ? 1 : ease((t - 2.7) / 1.2)
        rect(79, 184 - closed * 86, 202, 14 + closed * 76, 5, steel.opacity(0.1 + closed * 0.15))
        line(103, 189 - closed * 81, 257, 189 - closed * 81, steel, width: 5)
        if preheat {
            for i in 0..<3 {
                var p = Path(); let x = Double(133 + i * 44)
                p.move(to: .init(x: x, y: 168))
                p.addCurve(to: .init(x: x, y: 118), control1: .init(x: x - 15, y: 148), control2: .init(x: x + 15, y: 138))
                paint(p, stroke: gold.opacity(warm * 0.8), width: 2)
            }
        }
    }

    private mutating func bowl(time t: Double, mixing: Bool) {
        oval(69, 193, 222, 18, ink.opacity(0.06), width: 0)
        var p = Path(); p.move(to: .init(x: 65, y: 132))
        p.addQuadCurve(to: .init(x: 296, y: 132), control: .init(x: 180, y: 103))
        p.addQuadCurve(to: .init(x: 65, y: 132), control: .init(x: 180, y: 291))
        paint(p, fill: .white)
        oval(65, 110, 231, 67, .white)
        oval(77, 119, 208, 45, crumb.opacity(0.2), width: 0)
        for i in 0..<12 {
            let angle = Double(i) * 2.4 + (mixing ? min(t, 4.8) * 0.7 : 0)
            let x = 173 + cos(angle) * Double(30 + i % 3 * 20)
            let y = 132 + sin(angle) * Double(10 + i % 3 * 3)
            cubes(x, y, scale: 0.85)
        }
        for i in 0..<3 {
            let progress = mixing ? 1 : ease((t - 1.4 - Double(i) * 0.4) / 1)
            let saved = context; context.opacity = progress
            leaf(Double(130 + i * 42), 147 - 60 * (1 - progress), angle: Double(i * 50), scale: 0.65)
            context = saved
        }
        if !mixing && t < 3 { drizzle(x: 254, y: 81, time: t) }
        if mixing {
            let angle = min(t, 4.8) * 1.3
            let x = 178 + cos(angle) * 67
            let y = 139 + sin(angle) * 13
            oval(x - 14, y - 6, 30, 15, crust)
            line(x + 6, y - 3, x + 44, y - 74, crust, width: 7)
            line(x + 7, y - 6, x + 43, y - 72, crumb.opacity(0.65), width: 1.5)
        }
    }
}
