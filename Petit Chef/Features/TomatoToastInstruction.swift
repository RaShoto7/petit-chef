import SwiftUI

struct TomatoToastInstruction: View {
    let title: String
    let guide: TomatoToastGuide
    let temperatureUnit: String
    @State private var selected = 0
    @Environment(\.dynamicTypeSize) private var typeSize

    private var action: TomatoToastAction { guide.actions[selected] }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .accessibilityIdentifier("cooking.step.title")
            TomatoToastAnimation(gesture: action.gesture, temperatureUnit: temperatureUnit)
                .id(action.id)
            Text(CookingText.formatted(action.landmark, unit: temperatureUnit))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("toast.landmark")
            VStack(alignment: .leading, spacing: 10) {
                Text("LES GESTES · \(selected + 1)/\(guide.actions.count)")
                    .font(.caption.weight(.semibold)).tracking(1.2)
                    .foregroundStyle(.secondary)
                let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
                layout {
                    ForEach(Array(guide.actions.enumerated()), id: \.element.id) { index, item in
                        Button { selected = index } label: {
                            Text("\(index + 1). \(item.label)")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding(.horizontal, 5)
                                .background(selected == index ? DesignSystem.Colors.accent : DesignSystem.Colors.sage.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(selected == index ? .white : DesignSystem.Colors.ink)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Geste \(index + 1) sur \(guide.actions.count) : \(item.title)")
                        .accessibilityAddTraits(selected == index ? .isSelected : [])
                        .accessibilityIdentifier("toast.gesture.\(item.id)")
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(CookingText.formatted(action.title, unit: temperatureUnit))
                    .font(.headline)
                    .accessibilityIdentifier("toast.action.title")
                Text(CookingText.formatted(action.detail, unit: temperatureUnit))
                    .font(.body).lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("toast.action.detail")
            }
            if selected + 1 < guide.actions.count {
                Button { selected += 1 } label: {
                    Label("Geste suivant : \(guide.actions[selected + 1].label)", systemImage: "arrow.right")
                        .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                }
                .tint(DesignSystem.Colors.accent)
                .accessibilityIdentifier("toast.gesture.next")
            }
            VStack(alignment: .leading, spacing: 6) {
                Label("Le bon repère", systemImage: "eye")
                    .font(.subheadline.weight(.semibold))
                Text(guide.checkpoint).font(.subheadline).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Colors.sage.opacity(0.3), in: RoundedRectangle(cornerRadius: 18))
        }
    }
}
