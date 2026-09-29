import Foundation
import Testing
@testable import Petit_Chef

@MainActor
struct RecipeFlexibilityTests {
    private let origin = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func servingsScaleCustomIngredientsWithoutChangingDurations() throws {
        var draft = RecipeCustomization(recipe: RecipeCatalog.burgerAndFries)
        draft.groups[0].ingredients[0].quantity = 500
        draft.resize(to: 3)
        #expect(draft.groups[0].ingredients[0].quantity == 750)
        draft.resize(to: 2)
        #expect(draft.groups[0].ingredients[0].quantity == 500)
        draft.resize(to: 0)
        #expect(draft.servings == 2)
        #expect(draft.isValid)
    }

    @Test func ingredientEditsPersistAndResetIsAvailable() throws {
        let suite = "RecipeLibraryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let library = RecipeLibrary(defaults: defaults)
        let original = RecipeCatalog.burgerAndFries
        var draft = library.draft(for: original)
        draft.groups[1].ingredients.removeAll { $0.id == "onion" }
        draft.groups[1].ingredients.append(Ingredient(id: "pickle", name: "Cornichons", quantity: 2, unit: "", detail: nil))
        draft.resize(to: 4)
        library.save(draft, for: original.id)
        let restored = RecipeLibrary(defaults: defaults).recipe(from: original)
        #expect(restored.servings == 4)
        #expect(!restored.ingredientGroups.flatMap(\.ingredients).contains { $0.id == "onion" })
        #expect(restored.ingredientGroups.flatMap(\.ingredients).first { $0.id == "pickle" }?.quantity == 4)
        #expect(restored.steps == original.steps)
        library.reset(original.id)
        #expect(library.recipe(from: original) == original)
    }

    @Test func outOfOrderActionsRequireExplicitOverrideAndSurviveRestore() throws {
        let recipe = RecipeCatalog.burgerAndFries
        var engine = CookingEngine(recipe: recipe, now: origin)
        engine.performStep(id: "prepare-toppings", at: origin)
        #expect(engine.session.startedStepIDs.isEmpty)
        engine.performStep(id: "prepare-toppings", allowingOutOfOrder: true, at: origin)
        #expect(engine.session.completedStepIDs.contains("prepare-toppings"))
        let data = try JSONEncoder().encode(engine.session)
        let saved = try JSONDecoder().decode(CookingSession.self, from: data)
        let restored = try #require(CookingEngine(recipe: recipe, restoring: saved))
        #expect(restored.currentStep?.id == "preheat-and-wash")
        #expect(restored.session.overriddenStepIDs == ["prepare-toppings"])
    }

    @Test func rereadingAndRevalidatingNeverDuplicatesTimers() throws {
        var engine = CookingEngine(recipe: RecipeCatalog.burgerAndFries, now: origin)
        let started = engine.performStep(id: "bake-fries", allowingOutOfOrder: true, at: origin)
        let timer = try #require(started)
        engine.performStep(id: "bake-fries", allowingOutOfOrder: true, at: origin.addingTimeInterval(30))
        #expect(engine.session.timers.count == 1)
        #expect(engine.session.timers.first?.deadline == timer.deadline)
        let rejected = engine.confirmTimer(id: timer.id, at: origin)
        #expect(!rejected)
        let accepted = engine.confirmTimer(id: timer.id, allowingEarly: true, at: origin)
        #expect(accepted)
        #expect(engine.session.timers.isEmpty)
        #expect(engine.session.completedStepIDs.contains("bake-fries"))
    }

    @Test func shorteningTimerDoesNotConfirmFoodAndPersists() throws {
        var engine = CookingEngine(recipe: RecipeCatalog.burgerAndFries, now: origin)
        let started = engine.performStep(id: "bake-fries", allowingOutOfOrder: true, at: origin)
        let timer = try #require(started)
        engine.adjustTimer(id: timer.id, by: -60, at: origin)
        #expect(engine.session.timers.first?.remainingSeconds(at: origin) == 840)
        engine.adjustTimer(id: timer.id, by: -3600, at: origin)
        #expect(engine.session.timers.first?.remainingSeconds(at: origin) == 1)
        #expect(!engine.session.completedStepIDs.contains("bake-fries"))
        #expect(CookingEngine(recipe: RecipeCatalog.burgerAndFries, restoring: engine.session) != nil)
    }

    @Test func invalidIngredientEditsCannotBeSaved() {
        var draft = RecipeCustomization(recipe: RecipeCatalog.burgerAndFries)
        draft.groups[0].ingredients[0].quantity = -1
        #expect(!draft.isValid)
        draft.groups[0].ingredients[0].quantity = 3
        draft.groups[0].ingredients[0].name = "  "
        #expect(!draft.isValid)
    }
    @Test func manualDurationUsesApplyTimeAndSurvivesRestoration() throws {
        var engine = CookingEngine(recipe: RecipeCatalog.burgerAndFries, now: origin)
        let startedTimer = engine.performStep(id: "bake-fries", allowingOutOfOrder: true, at: origin)
        let timer = try #require(startedTimer)
        let applyDate = origin.addingTimeInterval(37)
        let accepted = engine.setTimerRemaining(id: timer.id, seconds: 125, at: applyDate)
        #expect(accepted)
        #expect(engine.session.timers.first?.deadline == applyDate.addingTimeInterval(125))
        #expect(engine.session.timers.first?.remainingSeconds(at: applyDate) == 125)
        #expect(!engine.session.completedStepIDs.contains("bake-fries"))
        let snapshot = engine.session
        for invalid in [0, -1, 86_400, Int.max] {
            let rejected = engine.setTimerRemaining(id: timer.id, seconds: invalid, at: applyDate)
            #expect(!rejected)
        }
        #expect(engine.session == snapshot)
        let data = try JSONEncoder().encode(snapshot)
        let restored = try #require(CookingEngine(recipe: RecipeCatalog.burgerAndFries, restoring: JSONDecoder().decode(CookingSession.self, from: data)))
        #expect(restored.session.timers.first?.remainingSeconds(at: applyDate.addingTimeInterval(25)) == 100)
    }

    @Test func editHistoryRestoresAdditionsDeletionsAndClearsRedoAfterBranching() {
        var draft = RecipeCustomization(recipe: RecipeCatalog.burgerAndFries)
        let original = draft
        var history = IngredientEditHistory()
        var edited = draft
        edited.groups[0].ingredients[0].name = "Agria"
        history.record(draft, replacingWith: edited)
        draft = edited
        var deleted = draft
        deleted.groups[0].ingredients.removeFirst()
        history.record(draft, replacingWith: deleted)
        draft = deleted
        history.undo(&draft)
        #expect(draft == edited)
        history.undo(&draft)
        #expect(draft == original)
        #expect(!history.canUndo)
        history.redo(&draft)
        #expect(draft == edited)
        var added = draft
        added.groups[0].ingredients.append(Ingredient(id: "added", name: "Herbes", quantity: nil, unit: "", detail: nil))
        history.record(draft, replacingWith: added)
        draft = added
        #expect(!history.canRedo)
        history.undo(&draft)
        #expect(draft == edited)
        history.redo(&draft)
        #expect(draft == added)
        history.record(draft, replacingWith: draft)
        #expect(history.undoStack.count == 2)
    }

}
