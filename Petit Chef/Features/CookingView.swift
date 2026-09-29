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
    @State private var editingTimer: CookingTimer?
    @State private var isAdvancing = false
    @State private var cardOffset: CGFloat = 0
    @State private var cardOpacity: Double = 1
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var advances = 0
    @State private var arrivalID: UUID?

    private var steps: [RecipeStep] { cooking.recipe?.steps ?? [] }
    private var position: Int { min(index ?? cooking.currentIndex, max(0, steps.count - 1)) }
    private var step: RecipeStep? { steps.indices.contains(position) ? steps[position] : nil }
    private var motion: Animation? { reduceMotion ? nil : .spring(response: 0.58, dampingFraction: 0.9) }
    private var started: Bool { step.map { cooking.engine?.session.startedStepIDs.contains($0.id) ?? false } ?? false }
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
            .chefScreen()
        }
        .task(id: arrivalID) {
            guard arrivalID != nil else { return }
            do { try await Task.sleep(for: .milliseconds(80)) } catch { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.65), completionCriteria: .removed) {
                cardOffset = 0
                cardOpacity = 1
            } completion: {
                isAdvancing = false
            }
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
                    VStack(spacing: 24) {
                        preparationScene(step)
                            .frame(height: 290)
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                        instruction(step)
                    }
                    .id(step.id)
                    .opacity(cardOpacity)
                    .offset(y: cardOffset)
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
            ToastSketchAnimation(stepID: step.id, isPlaying: !isAdvancing)
                .clipShape(.rect(cornerRadius: 32))
        } else {
            AnimatedCookingIllustration(stepID: step.id, recipeID: cooking.recipe?.id ?? "")
        }
    }

    private var navigationControls: some View {
        HStack {
            if position > 0 {
                ChefIconButton(symbol: "arrow.left", label: "Étape précédente") { move(to: position - 1) }
                    .disabled(isAdvancing)
                    .accessibilityIdentifier("cooking.previous")
            } else { Color.clear.frame(width: 44, height: 44).accessibilityHidden(true) }
            Spacer(minLength: 0)
            Button {
                advances += 1
                if started { move(to: min(position + 1, steps.count - 1)) }
                else if !missing.isEmpty { overrideStep = true }
                else { perform() }
            } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: 25, weight: .medium))
                    .frame(width: 64, height: 64)
                    .contentShape(.circle)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.regular)
            .disabled(isAdvancing || (started && position == steps.count - 1))
            .accessibilityLabel(actionTitle)
            .accessibilityHint("Valide cette étape et passe à la suivante")
            .accessibilityIdentifier("cooking.next")
            .sensoryFeedback(.impact(weight: .light), trigger: advances) { _, _ in hapticsEnabled }
            .contextMenu {
                if position < steps.count - 1 {
                    Button("Consulter l’étape suivante", systemImage: "arrow.right") { move(to: position + 1) }
                        .accessibilityIdentifier("cooking.skip")
                }
            }
            Spacer(minLength: 0)
            Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
        }
        .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 8)
        .frame(maxWidth: DesignSystem.Layout.maximumContentWidth)
        .frame(maxWidth: .infinity)
    }

    private var actionTitle: String {
        if started { return "Suivant" }
        if let timer = step?.timer { return "Lancer · \(timer.durationSeconds / 60) min" }
        return "Valider et continuer"
    }

    private func move(to target: Int) {
        guard steps.indices.contains(target), target != position else { return }
        transition(to: target)
    }

    private func perform(allowingOutOfOrder: Bool = false) {
        guard let step else { return }
        transition(to: min(position + 1, steps.count - 1)) {
            cooking.performStep(id: step.id, allowingOutOfOrder: allowingOutOfOrder)
        }
    }

    /// Finish the departure before swapping content, then unlock after arrival.
    /// Animation completion follows SwiftUI's actual duration, including slow animations.
    private func transition(to target: Int, action: (() -> Void)? = nil) {
        guard !isAdvancing else { return }
        isAdvancing = true
        let backwards = target < position
        if reduceMotion {
            action?()
            index = target
            isAdvancing = false
            return
        }
        withAnimation(.easeInOut(duration: 0.42), completionCriteria: .removed) {
            cardOffset = backwards ? 48 : -48
            cardOpacity = 0
        } completion: {
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) {
                action?()
                index = target
                cardOffset = backwards ? -64 : 64
                arrivalID = UUID()
            }
        }
    }

    private func stopTimer(_ timer: CookingTimer) {
        withAnimation(.smooth(duration: 0.35)) {
            _ = cooking.confirmTimer(id: timer.id, allowingEarly: true)
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
                        } label: { Image(systemName: "ellipsis").frame(width: 32, height: 44) }
                        .accessibilityLabel("Modifier le minuteur")
                        .accessibilityIdentifier("cooking.timer.options")
                        Button { stopTimer(timer) } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 44, height: 44)
                                .contentShape(.circle)
                        }
                        .buttonStyle(TactileButtonStyle())
                        .accessibilityLabel("Arrêter le minuteur \(timer.label)")
                        .accessibilityIdentifier("cooking.timer.stop")
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
            Button {
                onFinished()
            } label: {
                Text("Terminer")
                    .font(.system(.headline, design: .default, weight: .medium))
                    .padding(.horizontal, 40)
                    .frame(minHeight: 48)
                    .contentShape(.capsule)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .disabled(isAdvancing)
            .accessibilityIdentifier("cooking.finish")
        }
        .padding(24)
        .opacity(cardOpacity)
        .offset(y: cardOffset)
    }

    private func clock(_ seconds: Int) -> String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }
}
