import Foundation
import Testing
import UserNotifications
@testable import Petit_Chef

@MainActor
struct CookingEngineTests {
    private let origin = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func parallelPreparationRunsDuringCookingAndJoinRequiresBothChecks() throws {
        var engine = CookingEngine(recipe: parallelRecipe, now: origin)
        #expect(engine.currentStep?.id == "bake")
        let startedLongTimer = engine.advance(at: origin)
        let longTimer = try #require(startedLongTimer)
        #expect(engine.currentStep?.id == "chop")
        engine.advance(at: origin)
        #expect(engine.currentStep?.id == "warm")
        let startedShortTimer = engine.advance(at: origin)
        let shortTimer = try #require(startedShortTimer)
        #expect(engine.session.timers.count == 2)
        #expect(engine.status == .waiting)
        let confirmedEarly = engine.confirmTimer(id: longTimer.id, at: origin)
        #expect(!confirmedEarly)

        // Tapping through a waiting screen must not bypass either prerequisite.
        engine.advance(at: origin.addingTimeInterval(601))
        #expect(engine.currentStep == nil)
        let confirmedShortTimer = engine.confirmTimer(id: shortTimer.id, at: origin.addingTimeInterval(601))
        #expect(confirmedShortTimer)
        #expect(engine.currentStep == nil)
        let confirmedLongTimer = engine.confirmTimer(id: longTimer.id, at: origin.addingTimeInterval(601))
        #expect(confirmedLongTimer)
        #expect(engine.currentStep?.id == "serve")
        engine.advance(at: origin.addingTimeInterval(602))
        #expect(engine.status == .completed)
        #expect(engine.progress == 1)
        #expect(engine.session.timers.isEmpty)
    }

    @Test func restoredTimersUseWallClockAndNeverAutomaticallyReleaseFood() throws {
        var original = CookingEngine(recipe: parallelRecipe, now: origin)
        let startedTimer = original.advance(at: origin)
        let timer = try #require(startedTimer)
        let data = try JSONEncoder().encode(original.session)
        let session = try JSONDecoder().decode(CookingSession.self, from: data)
        let restored = try #require(CookingEngine(recipe: parallelRecipe, restoring: session))
        let afterLocking = origin.addingTimeInterval(480)
        #expect(restored.session.timers.first?.remainingSeconds(at: afterLocking) == 120)
        #expect(restored.session.timers.first?.remainingSeconds(at: origin.addingTimeInterval(700)) == 0)
        #expect(!restored.session.completedStepIDs.contains(timer.stepID))
        #expect(restored.currentStep?.id == "chop")
    }

    @Test func addingTimeRestartsExpiredReminderFromCurrentTime() throws {
        var engine = CookingEngine(recipe: parallelRecipe, now: origin)
        let startedTimer = engine.advance(at: origin)
        let timer = try #require(startedTimer)
        let late = origin.addingTimeInterval(900)
        let extended = engine.extendTimer(id: timer.id, by: 60, at: late)
        #expect(extended)
        #expect(engine.session.timers.first?.remainingSeconds(at: late) == 60)
        let confirmedBeforeExtension = engine.confirmTimer(id: timer.id, at: late)
        #expect(!confirmedBeforeExtension)
        let confirmedAfterExtension = engine.confirmTimer(id: timer.id, at: late.addingTimeInterval(60))
        #expect(confirmedAfterExtension)
        let confirmedTwice = engine.confirmTimer(id: timer.id, at: late.addingTimeInterval(61))
        #expect(!confirmedTwice)
    }

    @Test func remainingEstimateAccountsForOneCookAndParallelTimers() throws {
        var engine = CookingEngine(recipe: parallelRecipe, now: origin)
        #expect(engine.estimatedRemainingSeconds(at: origin) == 12 * 60)
        engine.advance(at: origin)
        #expect(engine.estimatedRemainingSeconds(at: origin) == 11 * 60)
        #expect(engine.estimatedRemainingSeconds(at: origin.addingTimeInterval(8 * 60)) == 5 * 60)
    }

    @Test func malformedPersistedGraphIsRejected() throws {
        let engine = CookingEngine(recipe: parallelRecipe, now: origin)
        var session = engine.session
        session.startedStepIDs = ["serve"]
        session.completedStepIDs = ["serve"]
        #expect(CookingEngine(recipe: parallelRecipe, restoring: session) == nil)
    }

    @Test func storeRestoresAndAbandonClearsTimersWithoutPromptingOnLaunch() async throws {
        let suite = "PetitChefCookingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let notifications = TestCookingNotifications()
        let store = CookingStore(recipes: [parallelRecipe], defaults: defaults, now: { origin }, notifications: notifications)
        await store.refreshNotifications()
        #expect(notifications.permissionRequests == 0)
        store.start(recipe: parallelRecipe)
        await store.requestNotificationPermission()
        store.advance()
        await store.refreshNotifications()
        #expect(notifications.scheduledTimers.count == 1)
        #expect(notifications.permissionRequests == 1)

        let restored = CookingStore(
            recipes: [parallelRecipe], defaults: defaults,
            now: { origin.addingTimeInterval(120) }, notifications: notifications
        )
        await restored.refreshNotifications()
        #expect(restored.currentStep?.id == "chop")
        #expect(restored.activeTimers.first?.remainingSeconds(at: origin.addingTimeInterval(120)) == 480)
        restored.abandon()
        await restored.refreshNotifications()
        #expect(notifications.scheduledTimers.isEmpty)
        #expect(defaults.data(forKey: "petitchef.cooking.session.v1") == nil)
    }

    @Test func startingAnotherRecipeDoesNotOverwriteAnActiveSession() async throws {
        let suite = "PetitChefCookingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let notifications = TestCookingNotifications()
        let store = CookingStore(recipes: [parallelRecipe, RecipeCatalog.burgerAndFries], defaults: defaults, notifications: notifications)
        store.setNotificationsEnabled(false)
        store.start(recipe: parallelRecipe)
        store.advance()
        let session = store.sessionID
        store.start(recipe: RecipeCatalog.burgerAndFries)
        await store.refreshNotifications()
        #expect(store.sessionID == session)
        #expect(store.recipe?.id == parallelRecipe.id)
        #expect(store.currentStep?.id == "chop")
        #expect(notifications.permissionRequests == 0)
        #expect(notifications.scheduledTimers.isEmpty)
    }

    @Test func failedPermissionRequestRemainsVisibleAfterSuccessfulTimerSync() async throws {
        let suite = "PetitChefCookingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let notifications = TestCookingNotifications()
        notifications.rejectsPermission = true
        let store = CookingStore(recipes: [parallelRecipe], defaults: defaults, notifications: notifications)
        await store.requestNotificationPermission()
        await store.refreshNotifications()
        #expect(store.notificationError != nil)
        notifications.rejectsPermission = false
        await store.requestNotificationPermission()
        #expect(store.notificationError == nil)
    }

    @Test func notificationPresentationWaitsForTheViewToConsumeIt() async throws {
        let suite = "PetitChefCookingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let notifications = TestCookingNotifications()
        let store = CookingStore(recipes: [parallelRecipe], defaults: defaults, notifications: notifications)
        store.start(recipe: parallelRecipe)
        notifications.onCookingRequested?()
        await store.refreshNotifications()
        #expect(store.presentationRequested)
        store.consumePresentationRequest()
        #expect(!store.presentationRequested)
        store.abandon()
        notifications.onCookingRequested?()
        #expect(!store.presentationRequested)
        await store.refreshNotifications()
    }

    private var parallelRecipe: Recipe {
        Recipe(
            id: "test-parallel", title: "Test", subtitle: "", heroImageName: "", cookingMethod: "Four",
            servings: 2, estimatedTotalMinutes: 12, ingredientGroups: [], equipment: [],
            steps: [
                step("bake", active: 1, passive: 10),
                step("chop", active: 2, startAfter: "bake"),
                step("warm", active: 1, passive: 1, dependencies: ["chop"], startAfter: "bake"),
                step("serve", active: 1, dependencies: ["bake", "warm"])
            ],
            tip: ""
        )
    }

    private func step(_ id: String, active: Int, passive: Int = 0, dependencies: [String] = [], startAfter: String? = nil) -> RecipeStep {
        RecipeStep(
            id: id, title: id, instruction: id, activeMinutes: active, passiveMinutes: passive,
            timingNote: nil, parallelNote: nil, dependencies: dependencies, startAfterStepID: startAfter,
            timer: passive == 0 ? nil : RecipeTimer(id: "timer-\(id)", label: id, durationSeconds: passive * 60)
        )
    }
}

@MainActor
private final class TestCookingNotifications: CookingNotificationScheduling {
    var onCookingRequested: (() -> Void)?
    var permissionRequests = 0
    var rejectsPermission = false
    var authorization: UNAuthorizationStatus = .notDetermined
    var scheduledTimers: [CookingTimer] = []

    func authorizationStatus() async -> UNAuthorizationStatus { authorization }

    func requestAuthorization() async throws -> Bool {
        permissionRequests += 1
        if rejectsPermission { throw CocoaError(.fileReadUnknown) }
        authorization = .authorized
        return true
    }

    func synchronize(timers: [CookingTimer], enabled: Bool, now: Date) async throws {
        scheduledTimers = enabled ? timers.filter { !$0.isExpired(at: now) } : []
    }
}
