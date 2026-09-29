import SwiftUI

enum DesignSystem {
    enum Colors {
        static let cream = Color.white
        static let sand = Color(hex: 0xEEE8DB)
        static let deepSand = Color(hex: 0xDEDCD5)
        static let terracotta = Color(hex: 0xC88363)
        static let sage = Color(hex: 0xDDE6D8)
        static let ink = Color(hex: 0x29322D)
        static let secondaryInk = Color(hex: 0x737A72)
        static let card = Color.white
        static let accent = Color(hex: 0x526B50)
    }

    enum Layout {
        static let pagePadding: CGFloat = 22
        static let cardRadius: CGFloat = 30
        static let maximumContentWidth: CGFloat = 620
    }

    enum Typography {
        static let title = Font.system(.largeTitle, design: .serif, weight: .medium).italic()
        static let editorial = Font.system(size: 40, weight: .regular, design: .serif).italic()
        static let section = Font.system(.title2, design: .rounded, weight: .bold)
        static let body = Font.system(.body, design: .rounded)
        static let label = Font.system(.subheadline, design: .rounded, weight: .semibold)
        static let caption = Font.system(.caption, design: .rounded, weight: .medium)
    }
}

/// Native glass supplies the optical interaction; this style is for illustrated cards.
struct TactileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var raised = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .shadow(color: DesignSystem.Colors.ink.opacity(raised ? 0.08 : 0),
                    radius: configuration.isPressed ? 1 : 10,
                    y: configuration.isPressed ? 1 : 5)
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

struct ChefCard<Content: View>: View {
    var tint: Color = .white
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        content
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.cardRadius)
                        .fill(Color(.secondarySystemGroupedBackground))
                }
            }
            .glassEffect(reduceTransparency ? .identity : .clear.tint(tint.opacity(0.12)),
                         in: .rect(cornerRadius: DesignSystem.Layout.cardRadius))
    }
}

struct ChefPrimaryButton: View {
    let title: String
    var symbol = "arrow.right"
    var action: () -> Void
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            HStack(spacing: 9) {
                Text(title)
                Image(systemName: symbol)
                    .fontWeight(.semibold)
            }
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .padding(.horizontal, 12)
            .frame(minHeight: 28)
        }
        .buttonStyle(.glass)
        .controlSize(.regular)
        .buttonBorderShape(.capsule)
        .tint(DesignSystem.Colors.ink)
        .sensoryFeedback(.impact(weight: .light), trigger: taps) { _, _ in hapticsEnabled }
    }
}

extension View {
    func chefScreen() -> some View {
        self
            .fontDesign(.rounded)
            .foregroundStyle(DesignSystem.Colors.ink)
            .background(DesignSystem.Colors.cream)
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// The visible disk stays light while preserving a comfortable 44-point touch target.
struct ChefIconButton: View {
    let symbol: String
    let label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 30)
                .glassEffect(.regular.interactive(), in: .circle)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel(label)
    }
}
