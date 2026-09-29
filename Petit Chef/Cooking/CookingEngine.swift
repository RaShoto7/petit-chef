import Foundation

nonisolated enum CookingStatus: String, Codable, Equatable, Sendable {
    case ready
    case cooking
    case waiting
    case completed
}

/// A deadline survives suspension and device locking; no decrementing counter is stored.
nonisolated struct CookingTimer: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let stepID: String
    let label: String
    let startedAt: Date
    var deadline: Date

    var durationSeconds: Int { max(1, Int(ceil(deadline.timeIntervalSince(startedAt)))) }

    func remaining(at date: Date) -> TimeInterval {
        max(0, deadline.timeIntervalSince(date))
    }

    func remainingSeconds(at date: Date) -> Int {
        Int(ceil(remaining(at: date)))
    }

    func isExpired(at date: Date) -> Bool { deadline <= date }

    func progress(at date: Date) -> Double {
        min(1, max(0, 1 - remaining(at: date) / Double(durationSeconds)))
    }
}

nonisolated struct CookingSession: Codable, Equatable, Sendable {
    let id: UUID
    let recipeID: String
    // Validate a restored schedule against its exact curated dependency graph.
    let recipeSteps: [RecipeStep]
    let startedAt: Date
    var startedStepIDs: Set<String> = []
    var completedStepIDs: Set<String> = []
    var timers: [CookingTimer] = []
    var completedAt: Date?
    var recipeSnapshot: Recipe?
    var overriddenStepIDs: Set<String>?
}

/// Pure state transitions. The UI, notifications and future chef language share this source of truth.
nonisolated struct CookingEngine: Sendable {
    let recipe: Recipe
    private(set) var session: CookingSession

    init(recipe: Recipe, now: Date = .now) {
        self.recipe = recipe
        session = CookingSession(id: UUID(), recipeID: recipe.id, recipeSteps: recipe.steps, startedAt: now, recipeSnapshot: recipe)
    }

    init?(recipe: Recipe, restoring session: CookingSession) {
        let stepIDs = Set(recipe.steps.map(\.id))
        let timerStepIDs = Set(session.timers.map(\.stepID))
        guard session.recipeID == recipe.id,
              session.recipeSteps == recipe.steps,
              stepIDs.count == recipe.steps.count,
              session.startedStepIDs.isSubset(of: stepIDs),
              (session.overriddenStepIDs ?? []).isSubset(of: session.startedStepIDs),
              session.completedStepIDs.isSubset(of: session.startedStepIDs),
              timerStepIDs.isSubset(of: session.startedStepIDs),
              timerStepIDs.isDisjoint(with: session.completedStepIDs),
              timerStepIDs.count == session.timers.count,
              Set(session.timers.map(\.id)).count == session.timers.count,
              session.startedStepIDs == session.completedStepIDs.union(timerStepIDs),
              session.timers.allSatisfy({ timer in
                  timer.id.hasPrefix("petitchef.timer.\(session.id.uuidString).") &&
                  timer.deadline > timer.startedAt &&
                  recipe.steps.contains { $0.id == timer.stepID && $0.timer != nil }
              }),
              recipe.steps.filter({ session.startedStepIDs.contains($0.id) }).allSatisfy({ step in
                  (session.overriddenStepIDs?.contains(step.id) ?? false) ||
                  (Set(step.dependencies).isSubset(of: session.completedStepIDs) &&
                  (step.startAfterStepID.map { session.startedStepIDs.contains($0) } ?? true))
              }),
              (session.completedAt != nil) == (session.completedStepIDs.count == recipe.steps.count)
        else { return nil }
        self.recipe = recipe
        self.session = session
    }

    var currentStep: RecipeStep? {
        recipe.steps.first { step in
            !session.startedStepIDs.contains(step.id) &&
            Set(step.dependencies).isSubset(of: session.completedStepIDs) &&
            (step.startAfterStepID.map { session.startedStepIDs.contains($0) } ?? true)
        }
    }

    var currentIndex: Int {
        guard let step = currentStep ?? recipe.steps.first(where: { !session.completedStepIDs.contains($0.id) })
        else { return max(0, recipe.steps.count - 1) }
        return recipe.steps.firstIndex(where: { $0.id == step.id }) ?? 0
    }

    var upcoming: [RecipeStep] {
        recipe.steps.filter { !session.startedStepIDs.contains($0.id) && $0.id != currentStep?.id }
    }

    var progress: Double {
        guard !recipe.steps.isEmpty else { return 1 }
        return Double(session.completedStepIDs.count) / Double(recipe.steps.count)
    }

    var status: CookingStatus {
        if session.completedAt != nil { return .completed }
        if currentStep == nil { return .waiting }
        return session.timers.isEmpty ? .ready : .cooking
    }

    /// Validating an instruction starts its passive phase, freeing the cook for a parallel instruction.
    @discardableResult
    mutating func advance(at date: Date) -> CookingTimer? {
        guard let step = currentStep else { return nil }
        return performStep(id: step.id, at: date)
    }

    func unmetDependencies(for step: RecipeStep) -> [String] {
        var missing = step.dependencies.filter { !session.completedStepIDs.contains($0) }
        if let previous = step.startAfterStepID, !session.startedStepIDs.contains(previous) { missing.append(previous) }
        return missing
    }

    /// Explicit overrides are recorded; merely browsing never mutates cooking state.
    @discardableResult
    mutating func performStep(id: String, allowingOutOfOrder: Bool = false, at date: Date) -> CookingTimer? {
        guard let step = recipe.steps.first(where: { $0.id == id }),
              !session.startedStepIDs.contains(id) else { return nil }
        let missing = unmetDependencies(for: step)
        guard missing.isEmpty || allowingOutOfOrder else { return nil }
        if !missing.isEmpty {
            var overrides = session.overriddenStepIDs ?? []
            overrides.insert(id)
            session.overriddenStepIDs = overrides
        }
        session.startedStepIDs.insert(step.id)
        if let definition = step.timer {
            let timer = CookingTimer(
                id: "petitchef.timer.\(session.id.uuidString).\(definition.id)",
                stepID: step.id,
                label: definition.label,
                startedAt: date,
                deadline: date.addingTimeInterval(TimeInterval(definition.durationSeconds))
            )
            session.timers.append(timer)
            return timer
        }
        session.completedStepIDs.insert(step.id)
        finishIfNeeded(at: date)
        return nil
    }

    /// Expiration is a reminder to inspect food. Only this explicit action releases its dependents.
    @discardableResult
    mutating func confirmTimer(id: String, allowingEarly: Bool = false, at date: Date) -> Bool {
        guard let timer = session.timers.first(where: { $0.id == id }), (allowingEarly || timer.isExpired(at: date))
        else { return false }
        session.timers.removeAll { $0.id == id }
        session.completedStepIDs.insert(timer.stepID)
        finishIfNeeded(at: date)
        return true
    }

    @discardableResult
    mutating func extendTimer(id: String, by seconds: Int = 60, at date: Date) -> Bool {
        guard seconds > 0, let index = session.timers.firstIndex(where: { $0.id == id }) else { return false }
        session.timers[index].deadline = max(session.timers[index].deadline, date).addingTimeInterval(TimeInterval(seconds))
        return true
    }

    @discardableResult
    mutating func adjustTimer(id: String, by seconds: Int, at date: Date) -> Bool {
        guard let index = session.timers.firstIndex(where: { $0.id == id }), seconds != 0 else { return false }
        session.timers[index].deadline = max(date.addingTimeInterval(1), session.timers[index].deadline.addingTimeInterval(TimeInterval(seconds)))
        return true
    }

    /// Replace the remaining duration from the moment the user applies the change.
    /// Invalid input cannot stop a timer or mark food as cooked.
    @discardableResult
    mutating func setTimerRemaining(id: String, seconds: Int, at date: Date) -> Bool {
        guard (1...86_399).contains(seconds),
              let index = session.timers.firstIndex(where: { $0.id == id }) else { return false }
        session.timers[index].deadline = date.addingTimeInterval(TimeInterval(seconds))
        return true
    }

    /// Deterministic estimate: one cook, ordered ready tasks, parallel passive phases.
    /// Waiting for the human to inspect an expired timer is intentionally not predicted.
    func estimatedRemainingSeconds(at date: Date) -> TimeInterval {
        guard status != .completed else { return 0 }
        var completed = session.completedStepIDs
        var started = session.startedStepIDs
        var deadlines = Dictionary(uniqueKeysWithValues: session.timers.map { ($0.stepID, $0.remaining(at: date)) })
        var time: TimeInterval = 0

        for _ in 0..<(recipe.steps.count * 3 + 1) {
            let elapsed = deadlines.filter { $0.value <= time }.map(\.key)
            for id in elapsed {
                completed.insert(id)
                deadlines.removeValue(forKey: id)
            }
            if completed.count == recipe.steps.count { return time }
            if let step = recipe.steps.first(where: { step in
                !started.contains(step.id) && Set(step.dependencies).isSubset(of: completed) &&
                (step.startAfterStepID.map { started.contains($0) } ?? true)
            }) {
                time += TimeInterval(step.activeMinutes * 60)
                started.insert(step.id)
                if let timer = step.timer {
                    deadlines[step.id] = time + TimeInterval(timer.durationSeconds)
                } else {
                    completed.insert(step.id)
                }
            } else if let nextDeadline = deadlines.values.min() {
                time = max(time, nextDeadline)
            } else {
                // Invalid curated graphs never invent a next action.
                return time
            }
        }
        return time
    }

    private mutating func finishIfNeeded(at date: Date) {
        if session.completedStepIDs.count == recipe.steps.count { session.completedAt = date }
    }
}
