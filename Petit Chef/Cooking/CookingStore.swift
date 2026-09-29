import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class CookingStore {
    private(set) var engine: CookingEngine?
    private(set) var notificationAuthorization: UNAuthorizationStatus = .notDetermined
    private(set) var notificationsEnabled: Bool
    private(set) var presentationRequested = false
    private var permissionError: String?
    private var schedulingError: String?

    @ObservationIgnored private let recipes: [Recipe]
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let persistenceKey: String
    @ObservationIgnored private let notificationPreferenceKey: String
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let notifications: any CookingNotificationScheduling
    @ObservationIgnored private let automaticallyRequestsPermission: Bool
    @ObservationIgnored private var notificationWork: Task<Void, Never>?
    @ObservationIgnored private var permissionRequestInFlight = false

    init(
        recipes: [Recipe] = RecipeCatalog.recipes,
        defaults: UserDefaults = .standard,
        persistenceKey: String = "petitchef.cooking.session.v1",
        now: @escaping () -> Date = { .now },
        notifications: (any CookingNotificationScheduling)? = nil,
        automaticallyRequestsPermission: Bool = !ProcessInfo.processInfo.arguments.contains("-ui-testing")
    ) {
        self.recipes = recipes
        self.defaults = defaults
        self.persistenceKey = persistenceKey
        self.notificationPreferenceKey = persistenceKey + ".notificationsEnabled"
        self.now = now
        self.notifications = notifications ?? (ProcessInfo.processInfo.arguments.contains("-ui-testing") ? CookingNotifications() as any CookingNotificationScheduling : CookingAlarms())
        self.automaticallyRequestsPermission = automaticallyRequestsPermission
        self.notificationsEnabled = defaults.object(forKey: notificationPreferenceKey) as? Bool ?? true
        if let data = defaults.data(forKey: persistenceKey),
           let session = try? JSONDecoder().decode(CookingSession.self, from: data),
           let recipe = recipes.first(where: { $0.id == session.recipeID }),
           session.recipeSteps == recipe.steps,
           let restored = CookingEngine(recipe: session.recipeSnapshot ?? recipe, restoring: session) {
            engine = restored
        } else {
            engine = nil
            defaults.removeObject(forKey: persistenceKey)
        }
        self.notifications.onCookingRequested = { [weak self] in
            guard let self, self.hasActiveSession else { return }
            self.presentationRequested = true
        }
        // Reading authorization never displays a prompt. Also clear obsolete reminders after a corrupt restore.
        Task { await refreshNotifications() }
    }

    var recipe: Recipe? { engine?.recipe }
    var notificationError: String? { permissionError ?? schedulingError }
    var sessionID: UUID? { engine?.session.id }
    var currentStep: RecipeStep? { engine?.currentStep }
    var currentIndex: Int { engine?.currentIndex ?? 0 }
    var progress: Double { engine?.progress ?? 0 }
    var status: CookingStatus { engine?.status ?? .ready }
    var activeTimers: [CookingTimer] { engine?.session.timers.sorted { $0.deadline < $1.deadline } ?? [] }
    var upcoming: [RecipeStep] { engine?.upcoming ?? [] }
    var hasActiveSession: Bool { engine != nil && status != .completed }
    var completedStepCount: Int { engine?.session.completedStepIDs.count ?? 0 }
    var estimatedRemainingMinutes: Int { Int(ceil(estimatedRemainingSeconds(at: now()) / 60)) }

    var buttonTitle: String {
        if status == .completed { return "À table !" }
        guard let step = currentStep else { return "La cuisson continue" }
        if let timer = step.timer {
            return "Lancer · \(max(1, timer.durationSeconds / 60)) min"
        }
        return upcoming.isEmpty && activeTimers.isEmpty ? "C’est prêt !" : "Étape suivante"
    }

    func estimatedRemainingSeconds(at date: Date) -> TimeInterval {
        engine?.estimatedRemainingSeconds(at: date) ?? 0
    }

    /// An existing session is resumed, never silently replaced by another recipe.
    func start(recipe: Recipe) {
        guard !hasActiveSession else { return }
        engine = CookingEngine(recipe: recipe, now: now())
        persistAndSync()
    }

    func advance() {
        guard var updated = engine else { return }
        let startedTimer = updated.advance(at: now())
        engine = updated
        persistAndSync()
        if startedTimer != nil && automaticallyRequestsPermission {
            Task {
                guard !activeTimers.isEmpty else { return }
                await requestPermissionIfNeeded(enableOnSuccess: false)
            }
        }
    }

    @discardableResult
    func confirmTimer(id: String, allowingEarly: Bool = false) -> Bool {
        guard var updated = engine, updated.confirmTimer(id: id, allowingEarly: allowingEarly, at: now()) else { return false }
        engine = updated
        persistAndSync()
        return true
    }

    func extendTimer(id: String, by seconds: Int = 60) {
        guard var updated = engine, updated.extendTimer(id: id, by: seconds, at: now()) else { return }
        engine = updated
        persistAndSync()
    }

    func performStep(id: String, allowingOutOfOrder: Bool = false) {
        guard var updated = engine else { return }
        let timer = updated.performStep(id: id, allowingOutOfOrder: allowingOutOfOrder, at: now())
        engine = updated
        persistAndSync()
        if timer != nil && automaticallyRequestsPermission {
            Task { await requestPermissionIfNeeded(enableOnSuccess: false) }
        }
    }

    func adjustTimer(id: String, by seconds: Int) {
        guard var updated = engine, updated.adjustTimer(id: id, by: seconds, at: now()) else { return }
        engine = updated
        persistAndSync()
    }

    func setTimerRemaining(id: String, seconds: Int) {
        guard var updated = engine, updated.setTimerRemaining(id: id, seconds: seconds, at: now()) else { return }
        engine = updated
        persistAndSync()
    }

    func abandon() {
        engine = nil
        presentationRequested = false
        persistAndSync()
    }

    func consumePresentationRequest() {
        presentationRequested = false
    }

    func dismissCompletedSession() {
        guard status == .completed else { return }
        abandon()
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        notificationsEnabled = enabled
        defaults.set(enabled, forKey: notificationPreferenceKey)
        enqueueNotificationSync()
        if enabled {
            Task { await requestPermissionIfNeeded(enableOnSuccess: false) }
        }
    }

    func requestNotificationPermission() async {
        await requestPermissionIfNeeded(enableOnSuccess: true)
    }

    func refreshNotifications() async {
        if defaults.bool(forKey: "petitchef.openCooking.request"), hasActiveSession {
            presentationRequested = true
            defaults.removeObject(forKey: "petitchef.openCooking.request")
        }
        notificationAuthorization = await notifications.authorizationStatus()
        enqueueNotificationSync()
        await notificationWork?.value
    }

    private func requestPermissionIfNeeded(enableOnSuccess: Bool) async {
        guard !permissionRequestInFlight else { return }
        guard notificationsEnabled || enableOnSuccess else { return }
        permissionRequestInFlight = true
        defer { permissionRequestInFlight = false }
        notificationAuthorization = await notifications.authorizationStatus()
        do {
            if notificationAuthorization == .notDetermined {
                _ = try await notifications.requestAuthorization()
                notificationAuthorization = await notifications.authorizationStatus()
            }
            if enableOnSuccess && canScheduleNotifications {
                notificationsEnabled = true
                defaults.set(true, forKey: notificationPreferenceKey)
            }
            permissionError = nil
        } catch {
            permissionError = "Les alarmes système n’ont pas pu être activées. Réessaie dans un instant."
        }
        enqueueNotificationSync()
        await notificationWork?.value
    }

    private var canScheduleNotifications: Bool {
        switch notificationAuthorization {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    private func persistAndSync() {
        if let session = engine?.session, let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: persistenceKey)
        } else {
            defaults.removeObject(forKey: persistenceKey)
        }
        enqueueNotificationSync()
    }

    private func enqueueNotificationSync() {
        let previous = notificationWork
        notificationWork = Task { [weak self] in
            // Serialize writes so an older async add can never resurrect an abandoned timer.
            await previous?.value
            guard let self else { return }
            do {
                try await notifications.synchronize(
                    timers: activeTimers,
                    enabled: notificationsEnabled && canScheduleNotifications,
                    now: now()
                )
                schedulingError = nil
            } catch {
                schedulingError = "Le rappel n’a pas pu être programmé. Garde Petit Chef ouvert pour suivre le minuteur."
            }
        }
    }
}
