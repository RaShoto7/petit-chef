import SwiftUI
import UIKit

struct CookingView: View {
    var onFinished: () -> Void
    @Environment(CookingStore.self) private var cooking
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("temperatureUnit") private var temperatureUnit = "celsius"
    @State private var index: Int?
    @State private var showOverview = false
    @State private var confirmStop = false
    @State private var overrideStep = false
    @State private var earlyTimer: CookingTimer?
    @State private var editingTimer: CookingTimer?
    @State private var isAdvancing = false
    @State private var backwards = false

    private var steps: [RecipeStep] { cooking.recipe?.steps ?? [] }
    private var position: Int { min(index ?? cooking.currentIndex, max(0, steps.count - 1)) }
    private var step: RecipeStep? { steps.indices.contains(position) ? steps[position] : nil }
    private var motion: Animation? { reduceMotion ? nil : .spring(response: 0.58, dampingFraction: 0.9) }
    private var started: Bool { step.map { cooking.engine?.session.startedStepIDs.contains($0.id) ?? false } ?? false }
    private var completed: Bool { step.map { cooking.engine?.session.completedStepIDs.contains($0.id) ?? false } ?? false }
    private var missing: [String] { step.flatMap { cooking.engine?.unmetDependencies(for: $0) } ?? [] }

    var body: some View {
        NavigationStack {
            Group {
                if cooking.status == .completed {
                    completion.transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97)))
                }
                else if let step { guided(step) }
                else { ContentUnavailableView("Aucune recette en cours", systemImage: "frying.pan") }
            }
            .navigationTitle(cooking.status == .completed ? "" : cooking.recipe?.shortTitle ?? "Recette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if cooking.status != .completed {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Réduire", systemImage: "chevron.down") { dismiss() }
                            .labelStyle(.iconOnly).accessibilityIdentifier("cooking.minimize")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Toutes les étapes", systemImage: "list.number") { showOverview = true }
                            Button("Arrêter la recette", systemImage: "xmark.circle", role: .destructive) { confirmStop = true }
                        } label: { Image(systemName: "ellipsis") }
                        .accessibilityIdentifier("cooking.options")
                    }
                }
            }
            .sheet(isPresented: $showOverview) { overview }
            .sheet(item: $editingTimer) { timer in
                TimerDurationEditor(label: timer.label, seconds: max(1, timer.remainingSeconds(at: .now))) { seconds in
                    withAnimation(motion) { cooking.setTimerRemaining(id: timer.id, seconds: seconds) }
                }
            }
            .confirmationDialog("Arrêter la recette ?", isPresented: $confirmStop, titleVisibility: .visible) {
                Button("Arrêter et annuler les minuteurs", role: .destructive) { cooking.abandon(); dismiss() }
            }
            .confirmationDialog("Avancer cette étape ?", isPresented: $overrideStep, titleVisibility: .visible) {
                Button("Effectuer maintenant") { perform(allowingOutOfOrder: true) }
            } message: {
                Text("Étapes prévues avant celle-ci : " + missing.compactMap { id in steps.first { $0.id == id }?.title }.joined(separator: ", ") + ". Les autres minuteurs continuent.")
            }
            .confirmationDialog("Terminer ce minuteur ?", isPresented: Binding(get: { earlyTimer != nil }, set: { if !$0 { earlyTimer = nil } }), titleVisibility: .visible) {
                if let timer = earlyTimer {
                    Button("Cuisson vérifiée · terminer") {
                        withAnimation(motion) { _ = cooking.confirmTimer(id: timer.id, allowingEarly: true) }
                        earlyTimer = nil
                    }
                }
            } message: { Text("Cette action arrête le rappel. Vérifie la cuisson avant de confirmer.") }
            .chefScreen()
        }
        .onAppear { index = cooking.currentIndex; UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: scenePhase) { _, phase in UIApplication.shared.isIdleTimerDisabled = phase == .active }
    }

    private func guided(_ step: RecipeStep) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    Color.clear.frame(height: 1).id("top")
                    preparationScene(step)
                        .frame(height: 290)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                    ZStack {
                        instruction(step)
                            .id(step.id)
                            .transition(reduceMotion ? .opacity : .asymmetric(
                                insertion: .modifier(active: StepArrival(offset: backwards ? -130 : 160, opacity: 0, scale: 0.97), identity: StepArrival()),
                                removal: .modifier(active: StepArrival(offset: backwards ? 100 : -140, opacity: 0, scale: 0.98), identity: StepArrival())))
                    }
                    if !cooking.activeTimers.isEmpty { timers }
                    if let error = cooking.notificationError {
                        Text(error).font(.caption).foregroundStyle(.secondary)
                    }
                    if position == steps.count - 1 && started && cooking.hasActiveSession {
                        Button("Voir les étapes restantes") { showOverview = true }
                            .buttonStyle(.glass).controlSize(.large)
                    }
                }
                .padding(.horizontal, DesignSystem.Layout.pagePadding)
                .padding(.bottom, 18)
                .frame(maxWidth: DesignSystem.Layout.maximumContentWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .onChange(of: position) { _, _ in
                // A second scroll animation would fight the card transition.
                var transaction = Transaction(); transaction.disablesAnimations = true
                withTransaction(transaction) { proxy.scrollTo("top", anchor: .top) }
            }
        }
        .safeAreaInset(edge: .bottom) { navigationControls }
    }

    private func instruction(_ step: RecipeStep) -> some View {
        ChefCard {
            VStack(alignment: .leading, spacing: 20) {
                Text(step.title)
                    .font(.system(.title, design: .serif, weight: .regular).italic())
                    .fontDesign(.serif)
                    .italic()
                    .tracking(-0.6)
                    .accessibilityIdentifier("cooking.step.title")
                Text(CookingText.formatted(step.instruction, unit: temperatureUnit))
                    .font(.body).lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func preparationScene(_ step: RecipeStep) -> some View {
        if cooking.recipe?.id == "tomato-mozzarella-toast" {
            ToastPreparationView(stepID: step.id, isAnimated: !reduceMotion && scenePhase == .active)
                .clipShape(.rect(cornerRadius: 32))
        } else {
            AnimatedCookingIllustration(stepID: step.id, recipeID: cooking.recipe?.id ?? "")
        }
    }

    private var navigationControls: some View {
        HStack(spacing: 16) {
            if position > 0 {
                ChefIconButton(symbol: "arrow.left", label: "Étape précédente") { move(to: position - 1) }
                    .disabled(isAdvancing)
                    .accessibilityIdentifier("cooking.previous")
            } else { Color.clear.frame(width: 44, height: 44).accessibilityHidden(true) }
            Spacer(minLength: 0)
            ChefPrimaryButton(title: actionTitle, symbol: started ? "arrow.right" : step?.timer != nil ? "timer" : "arrow.right") {
                if started { move(to: min(position + 1, steps.count - 1)) }
                else if !missing.isEmpty { overrideStep = true }
                else { perform() }
            }
            .disabled(isAdvancing || (started && position == steps.count - 1))
            .accessibilityIdentifier("cooking.next")
            Spacer(minLength: 0)
            if position < steps.count - 1 {
                ChefIconButton(symbol: "arrow.right", label: "Consulter l’étape suivante") { move(to: position + 1) }
                    .disabled(isAdvancing)
                    .accessibilityIdentifier("cooking.skip")
            } else { Color.clear.frame(width: 44, height: 44).accessibilityHidden(true) }
        }
        .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 6)
        .frame(maxWidth: DesignSystem.Layout.maximumContentWidth)
        .frame(maxWidth: .infinity)
    }

    private var actionTitle: String {
        if started { return "Suivant" }
        if let timer = step?.timer { return "Lancer · \(timer.durationSeconds / 60) min" }
        return "C’est fait"
    }

    private func move(to target: Int) {
        guard steps.indices.contains(target), !isAdvancing else { return }
        guard target != position else { return }
        backwards = target < position
        lockTransition()
        withAnimation(motion) { index = target }
    }

    private func perform(allowingOutOfOrder: Bool = false) {
        guard let step, !isAdvancing else { return }
        lockTransition()
        backwards = false
        withAnimation(motion) {
            cooking.performStep(id: step.id, allowingOutOfOrder: allowingOutOfOrder)
            if position < steps.count - 1 { index = position + 1 }
        }
    }

    private func lockTransition() {
        isAdvancing = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(580))
            isAdvancing = false
        }
    }

    private var timers: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 12) {
                ForEach(cooking.activeTimers) { timer in
                    HStack(spacing: 12) {
                        Image(systemName: cooking.notificationAuthorization != .authorized || !cooking.notificationsEnabled ? "bell.slash" : "timer")
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .accessibilityLabel(cooking.notificationAuthorization != .authorized || !cooking.notificationsEnabled ? "Alertes désactivées" : "Minuteur système")
                            .accessibilityIdentifier(cooking.notificationAuthorization != .authorized || !cooking.notificationsEnabled ? "cooking.timer.muted" : "cooking.timer.system")
                        VStack(alignment: .leading, spacing: 4) {
                            Text(timer.label).font(.subheadline.weight(.medium))
                            if timer.isExpired(at: context.date) { Text("À vérifier").font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer(minLength: 4)
                        Button { editingTimer = timer } label: {
                            Text(clock(timer.remainingSeconds(at: context.date)))
                                .font(.title3.monospacedDigit())
                                .contentTransition(.numericText(countsDown: true))
                                .accessibilityIdentifier("cooking.timer.value")
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(TactileButtonStyle())
                        .accessibilityLabel("Régler le minuteur")
                        .accessibilityValue(clock(timer.remainingSeconds(at: context.date)))
                        .accessibilityIdentifier("cooking.timer.edit")
                        Menu {
                            Button("Régler la durée…", systemImage: "dial.low") { editingTimer = timer }
                            Button("Ajouter 1 minute", systemImage: "plus") { cooking.extendTimer(id: timer.id) }
                            Button("Retirer 1 minute", systemImage: "minus") { cooking.adjustTimer(id: timer.id, by: -60) }
                            Button("Terminer maintenant", systemImage: "checkmark") { earlyTimer = timer }
                        } label: { Image(systemName: "ellipsis").frame(width: 32, height: 44) }
                        .accessibilityLabel("Modifier le minuteur")
                        .accessibilityIdentifier("cooking.timer.options")
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(DesignSystem.Colors.sage.opacity(0.20), in: RoundedRectangle(cornerRadius: 22))
                }
            }
        }
    }

    private var overview: some View {
        NavigationStack {
            List {
                ForEach(Array(steps.enumerated()), id: \.element.id) { i, item in
                    Button {
                        move(to: i)
                        showOverview = false
                    } label: {
                        HStack(spacing: 14) {
                            Text("\(i + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 20)
                            Text(item.title).foregroundStyle(DesignSystem.Colors.ink)
                            Spacer()
                            if cooking.engine?.session.completedStepIDs.contains(item.id) == true {
                                Image(systemName: "checkmark").foregroundStyle(DesignSystem.Colors.accent)
                            } else if cooking.activeTimers.contains(where: { $0.stepID == item.id }) {
                                Image(systemName: "timer").foregroundStyle(DesignSystem.Colors.accent)
                            }
                        }.padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Étapes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { showOverview = false } } }
        }
    }

    private var completion: some View {
        VStack(spacing: 24) {
            RecipeArtwork(recipeID: cooking.recipe?.id ?? "").frame(height: 250)
            Text("À vous de savourer.").font(DesignSystem.Typography.title).fontDesign(.serif).italic()
                .accessibilityIdentifier("cooking.completed")
            ChefPrimaryButton(title: "Terminer", symbol: "checkmark", action: onFinished)
                .accessibilityIdentifier("cooking.finish")
        }.padding(24)
    }

    private func clock(_ seconds: Int) -> String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }
}

private struct StepArrival: ViewModifier {
    var offset: CGFloat = 0
    var opacity: Double = 1
    var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content.scaleEffect(scale, anchor: .top).opacity(opacity).offset(y: offset)
    }
}
