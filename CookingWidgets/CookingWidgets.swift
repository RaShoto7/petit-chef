import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

@main
struct CookingWidgets: WidgetBundle {
    var body: some Widget { CookingCountdown() }
}

struct CookingCountdown: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<CookingAlarmMetadata>.self) { context in
            HStack(spacing: 16) {
                Image(systemName: "timer").font(.title2)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Petit Chef").font(.caption).foregroundStyle(.secondary)
                    Text(context.attributes.metadata?.label ?? "Cuisson").font(.headline)
                }
                Spacer()
                countdown(context.state).font(.title.monospacedDigit()).frame(maxWidth: 110)
            }
            .padding(20)
            .activityBackgroundTint(.white.opacity(0.9))
            .activitySystemActionForegroundColor(.primary)
            .widgetURL(URL(string: "petitchef://cooking"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer").foregroundStyle(.orange).padding(.top, 5)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context.state).font(.title2.monospacedDigit()).frame(width: 95)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.attributes.metadata?.label ?? "Cuisson").font(.subheadline)
                        Spacer()
                        Link(destination: URL(string: "petitchef://cooking")!) {
                            Image(systemName: "arrow.up.forward.app").accessibilityLabel("Ouvrir la recette")
                        }
                    }.padding(.top, 8)
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(.orange)
            } compactTrailing: {
                countdown(context.state).font(.caption.monospacedDigit()).frame(width: 48)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(.orange)
            }
            .widgetURL(URL(string: "petitchef://cooking"))
            .keylineTint(.orange)
        }
    }

    @ViewBuilder
    private func countdown(_ state: AlarmPresentationState) -> some View {
        switch state.mode {
        case .countdown(let countdown):
            Text(timerInterval: countdown.startDate...max(countdown.startDate, countdown.fireDate), countsDown: true)
                .monospacedDigit().multilineTextAlignment(.trailing)
        case .paused:
            Text("Pause").font(.caption)
        case .alert:
            Text("00:00").monospacedDigit()
        @unknown default:
            Image(systemName: "timer")
        }
    }
}
