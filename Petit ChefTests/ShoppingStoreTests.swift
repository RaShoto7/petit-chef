import Foundation
import Testing
@testable import Petit_Chef

@MainActor
struct ShoppingStoreTests {
    @Test func exportUsesAdjustedSnapshotAndOnlySelectedIngredients() throws {
        let suite = "ShoppingTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let library = RecipeLibrary(defaults: defaults)
        let original = RecipeCatalog.burgerAndFries
        library.resize(original, to: 4)
        let store = ShoppingStore(defaults: defaults)
        let id = store.create(title: "  Ce soir  ")
        store.add(recipe: library.recipe(from: original), ingredientIDs: ["potatoes"], to: id)
        library.resize(original, to: 2)
        let list = try #require(store.list(id))
        #expect(list.title == "Ce soir")
        #expect(list.items.count == 1)
        #expect(list.items[0].amount == "1 200 g" || list.items[0].amount == "1200 g")
        #expect(list.items[0].source?.contains("4 pers.") == true)
        #expect(list.remainingCount == 1)
        #expect(ShoppingStore(defaults: defaults).list(id) == list)
    }

    @Test func checkingEditingAndDeletionPersistWithoutAffectingOtherLists() throws {
        let suite = "ShoppingTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShoppingStore(defaults: defaults)
        let id = store.create(title: "")
        let other = store.create(title: "Demain")
        store.addItem(name: "  Pain  ", amount: "1", to: id)
        store.addItem(name: "  ", amount: "", to: id)
        let item = try #require(store.list(id)?.items.first)
        store.toggle(item.id, in: id)
        store.rename(id, to: "Marché")
        let restored = ShoppingStore(defaults: defaults)
        #expect(restored.list(id)?.remainingCount == 0)
        #expect(restored.list(id)?.items.count == 1)
        #expect(restored.list(id)?.shareText == "Marché\n\n☑ Pain · 1")
        restored.toggle(item.id, in: id)
        #expect(restored.list(id)?.remainingCount == 1)
        restored.removeItem(item.id, from: id)
        #expect(restored.list(id)?.items.isEmpty == true)
        restored.delete(id)
        #expect(ShoppingStore(defaults: defaults).lists.map(\.id) == [other])
    }

    @Test func multipleRecipesKeepContributionsAndCheckedItemsSeparate() throws {
        let suite = "ShoppingTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShoppingStore(defaults: defaults)
        let id = store.create(title: "Week-end")
        let recipe = RecipeCatalog.burgerAndFries
        store.add(recipe: recipe, ingredientIDs: ["potatoes"], to: id)
        let first = try #require(store.list(id)?.items.first)
        store.toggle(first.id, in: id)
        store.add(recipe: recipe, ingredientIDs: ["potatoes"], to: id)
        let items = try #require(store.list(id)?.items)
        #expect(items.count == 2)
        #expect(items[0].id != items[1].id)
        #expect(items[0].isChecked)
        #expect(!items[1].isChecked)
        #expect(store.list(id)?.remainingCount == 1)
    }
}
