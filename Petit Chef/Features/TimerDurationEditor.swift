import SwiftUI

struct TimerDurationEditor: View {
    let label: String
    var onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var hours: Int
    @State private var minutes: Int
    @State private var seconds: Int

    init(label: String, seconds: Int, onSave: @escaping (Int) -> Void) {
        self.label = label
        self.onSave = onSave
        let duration = min(86_399, max(1, seconds))
        _hours = State(initialValue: duration / 3600)
        _minutes = State(initialValue: duration % 3600 / 60)
        _seconds = State(initialValue: duration % 60)
    }

    private var duration: Int { hours * 3600 + minutes * 60 + seconds }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text("Temps restant").font(.title2.weight(.semibold))
                    Text(label).font(.subheadline).foregroundStyle(.secondary)
                }.padding(.top, 12)
                HStack(spacing: 0) {
                    wheel("h", selection: $hours, range: 0..<24, id: "timer.hours")
                    wheel("min", selection: $minutes, range: 0..<60, id: "timer.minutes")
                    wheel("s", selection: $seconds, range: 0..<60, id: "timer.seconds")
                }.frame(height: 150).clipped()
                ChefPrimaryButton(title: "Appliquer", symbol: "checkmark") {
                    onSave(duration); dismiss()
                }.disabled(duration == 0).accessibilityIdentifier("timer.apply")
                Spacer(minLength: 0)
            }.padding(.horizontal, 20)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly)
                }
            }
            .chefScreen()
        }
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }

    private func wheel(_ unit: String, selection: Binding<Int>, range: Range<Int>, id: String) -> some View {
        HStack(spacing: 0) {
            Picker(unit, selection: selection) {
                ForEach(range, id: \.self) { Text("\($0)").font(.title2.monospacedDigit()).tag($0) }
            }.pickerStyle(.wheel).labelsHidden().accessibilityIdentifier(id)
            Text(unit).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
