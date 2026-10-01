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

    @Test func compatibleIngredientsMergeWithRecipeBreakdownAndPersist() throws {
        let suite = "ShoppingTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShoppingStore(defaults: defaults)
        let id = store.create(title: "Semaine")
        store.add(recipe: RecipeCatalog.burgerAndFries, ingredientIDs: ["tomato", "seasoning"], to: id)
        store.add(recipe: RecipeCatalog.tomatoToast, ingredientIDs: ["tomatoes", "salt-pepper"], to: id)
        let list = try #require(store.list(id))
        #expect(list.items.count == 2)
        let tomato = try #require(list.items.first { $0.mergeName == "tomate" })
        #expect(tomato.quantity == 3)
        #expect(tomato.amount == "3")
        #expect(tomato.contributions?.map(\.amount) == ["1", "2"])
        #expect(tomato.contributions?.map(\.recipe.recipeID) == ["burger-and-oven-fries", "tomato-mozzarella-toast"])
        #expect(list.recipes.count == 2)
        #expect(list.shareText.contains("Burger & frites · 2 pers. : 1"))
        #expect(list.shareText.contains("Tartines tomate & mozzarella · 2 pers. : 2"))
        #expect(ShoppingStore(defaults: defaults).list(id) == list)
    }

    @Test func differentUnitsNamesAndFreeTextNeverMerge() throws {
        let suite = "ShoppingTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShoppingStore(defaults: defaults)
        let id = store.create(title: "Semaine")
        store.add(recipe: RecipeCatalog.burgerAndFries, ingredientIDs: ["tomato"], to: id)
        var recipe = RecipeCatalog.tomatoToast
        recipe.ingredientGroups[0].ingredients[1].quantity = 200
        recipe.ingredientGroups[0].ingredients[1].unit = "g"
        store.add(recipe: recipe, ingredientIDs: ["tomatoes"], to: id)
        recipe.ingredientGroups[0].ingredients[1].unit = "kg"
        recipe.ingredientGroups[0].ingredients[1].quantity = 0.2
        store.add(recipe: recipe, ingredientIDs: ["tomatoes"], to: id)
        recipe.ingredientGroups[0].ingredients[1].name = "Tomates séchées"
        store.add(recipe: recipe, ingredientIDs: ["tomatoes"], to: id)
        store.addItem(name: "Tomate", amount: "2", to: id)
        #expect(store.list(id)?.items.count == 5)
    }

    @Test func aislesCanBeCorrectedAndTemplatesAreIndependentUncheckedSnapshots() throws {
        let suite = "ShoppingTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShoppingStore(defaults: defaults)
        let id = store.create(title: "Marché")
        store.add(recipe: RecipeCatalog.burgerAndFries, ingredientIDs: ["tomato"], to: id)
        let item = try #require(store.list(id)?.items.first)
        #expect(item.aisle == .produce)
        store.setAisle(.pantry, for: item.id, in: id)
        store.toggle(item.id, in: id)
        store.saveTemplate(from: id, title: "  Mes essentiels  ")
        let restored = ShoppingStore(defaults: defaults)
        let template = try #require(restored.templates.first)
        #expect(template.title == "Mes essentiels")
        #expect(template.remainingCount == 1)
        let reused = try #require(restored.useTemplate(template.id))
        let copy = try #require(restored.list(reused))
        #expect(copy.id != id && copy.id != template.id)
        #expect(copy.items[0].id != item.id)
        #expect(copy.items[0].aisle == .pantry)
        #expect(copy.items[0].contributions == item.contributions)
        restored.toggle(copy.items[0].id, in: reused)
        restored.delete(id)
        #expect(restored.templates[0].remainingCount == 1)
        let second = try #require(restored.useTemplate(template.id))
        #expect(restored.list(second)?.remainingCount == 1)
        let duplicate = try #require(restored.duplicate(reused))
        #expect(restored.list(duplicate)?.remainingCount == 1)
        restored.deleteTemplate(template.id)
        #expect(ShoppingStore(defaults: defaults).templates.isEmpty)
        #expect(ShoppingStore(defaults: defaults).list(reused) != nil)
    }

    @Test func oldSavedListsMigrateWithoutLosingPurchasesOrSource() throws {
        let suite = "ShoppingTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let listID = UUID(), itemID = UUID()
        let legacy = """
        [{"id":"\(listID)","title":"Courses","items":[{"id":"\(itemID)","name":"Parmesan","amount":"50 g","source":"Pâtes au citron · 2 pers.","isChecked":true}]}]
        """
        defaults.set(Data(legacy.utf8), forKey: "petitchef.shopping.lists.v1")
        let store = ShoppingStore(defaults: defaults)
        let item = try #require(store.list(listID)?.items.first)
        #expect(item.id == itemID && item.isChecked)
        #expect(item.aisle == .dairy)
        #expect(item.sourceLabel == "Pâtes au citron · 2 pers.")
        store.toggle(itemID, in: listID)
        store.add(recipe: RecipeCatalog.lemonPasta, ingredientIDs: ["parmesan"], to: listID)
        #expect(store.list(listID)?.items.count == 2)
        #expect(ShoppingStore(defaults: defaults).list(listID)?.items.first?.amount == "50 g")
    }

    @Test func exportPortionsScaleAdjustedIngredientsWithoutSavingRecipeChanges() throws {
        let suite = "ShoppingTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let library = RecipeLibrary(defaults: defaults)
        let original = RecipeCatalog.burgerAndFries
        var customized = library.draft(for: original)
        customized.groups[0].ingredients[0].quantity = 800
        library.save(customized, for: original.id)
        let adjusted = library.recipe(from: original)
        var export = RecipeCustomization(recipe: adjusted)
        export.resize(to: 4)
        var exportedRecipe = adjusted
        exportedRecipe.servings = export.servings
        exportedRecipe.ingredientGroups = export.groups
        let store = ShoppingStore(defaults: defaults)
        let id = store.create(title: "Courses")
        store.add(recipe: exportedRecipe, ingredientIDs: ["potatoes"], to: id)
        #expect(store.list(id)?.items.first?.quantity == 1600)
        #expect(store.list(id)?.recipes.first?.servings == 4)
        #expect(library.recipe(from: original) == adjusted)
        #expect(library.recipe(from: original).servings == 2)
    }

    @Test func aisleSuggestionsUseWholeWordsAndKeepUnknownItemsInOther() {
        #expect(ShoppingAisle.suggested(for: "Huile d’olive") == .pantry)
        #expect(ShoppingAisle.suggested(for: "Steaks hachés de bœuf") == .meat)
        #expect(ShoppingAisle.suggested(for: "Laitue") == .produce)
        #expect(ShoppingAisle.suggested(for: "Citrons surgelés") == .frozen)
        #expect(ShoppingAisle.suggested(for: "Produit inconnu") == .other)
    }


    @Test func editingKeepsHistoricalContributionsAndPreventsFutureAutomaticMerges() throws {
        let suite = "ShoppingTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShoppingStore(defaults: defaults)
        let id = store.create(title: "Semaine")
        store.add(recipe: RecipeCatalog.burgerAndFries, ingredientIDs: ["tomato"], to: id)
        store.add(recipe: RecipeCatalog.tomatoToast, ingredientIDs: ["tomatoes"], to: id)
        let original = try #require(store.list(id)?.items.first)
        store.editItem(original.id, in: id, name: "  Tomates cerises  ", amount: "  500 g  ", aisle: .produce)
        let edited = try #require(store.list(id)?.items.first)
        #expect(edited.name == "Tomates cerises" && edited.amount == "500 g")
        #expect(edited.contributions == original.contributions)
        #expect(edited.contributions?.map(\.ingredientName) == ["Tomate", "Tomates"])
        #expect(edited.quantity == nil && edited.unit == nil && edited.isManuallyEdited == true)
        #expect(ShoppingStore(defaults: defaults).list(id)?.items.first == edited)
        store.undoLastChange(in: id)
        #expect(store.list(id)?.items.first == original)
        store.editItem(original.id, in: id, name: "Tomate", amount: "5", aisle: .produce)
        store.add(recipe: RecipeCatalog.burgerAndFries, ingredientIDs: ["tomato"], to: id)
        #expect(store.list(id)?.items.count == 2)
        #expect(store.list(id)?.items.first?.amount == "5")
        #expect(store.undoActions[id] == nil)
    }

    @Test func undoRestoresCheckDeletionAndAisleWithoutChangingOtherLists() throws {
        let suite = "ShoppingTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShoppingStore(defaults: defaults)
        let id = store.create(title: "Courses"), other = store.create(title: "Demain")
        for name in ["Pain", "Citron", "Beurre"] { store.addItem(name: name, amount: "1", to: id) }
        store.addItem(name: "Lait", amount: "1 l", to: other)
        let original = try #require(store.list(id))
        let item = original.items[1]
        store.toggle(item.id, in: id)
        #expect(store.list(id)?.items[1].isChecked == true)
        store.undoLastChange(in: id)
        #expect(store.list(id) == original)
        store.removeItem(item.id, from: id)
        #expect(store.list(id)?.items.count == 2)
        store.toggle(try #require(store.list(other)?.items.first?.id), in: other)
        store.undoLastChange(in: id)
        #expect(store.list(id) == original)
        #expect(store.list(other)?.items.first?.isChecked == true)
        store.setAisle(.pantry, for: item.id, in: id)
        store.undoLastChange(in: id)
        #expect(store.list(id) == original)
        #expect(ShoppingStore(defaults: defaults).list(id) == original)
        #expect(ShoppingStore(defaults: defaults).undoActions.isEmpty)
        store.removeItem(original.items[0].id, from: id)
        store.removeItem(original.items[2].id, from: id)
        store.undoLastChange(in: id)
        #expect(store.list(id)?.items.map(\.id) == [original.items[1].id, original.items[2].id])
        store.undoLastChange(in: id)
        #expect(store.list(id)?.items.count == 2)
    }

    @Test func invalidAndUnchangedEditsPreserveUndoAndAisleOnlyEditsKeepMerging() throws {
        let suite = "ShoppingTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShoppingStore(defaults: defaults)
        let id = store.create(title: "Courses")
        store.add(recipe: RecipeCatalog.burgerAndFries, ingredientIDs: ["tomato"], to: id)
        let item = try #require(store.list(id)?.items.first)
        store.editItem(item.id, in: id, name: item.name, amount: item.amount, aisle: .pantry)
        #expect(store.list(id)?.items.first?.quantity == 1)
        let undoID = store.undoActions[id]?.id
        store.editItem(item.id, in: id, name: "  ", amount: "2", aisle: .produce)
        store.editItem(item.id, in: id, name: item.name, amount: item.amount, aisle: .pantry)
        #expect(store.undoActions[id]?.id == undoID)
        store.add(recipe: RecipeCatalog.tomatoToast, ingredientIDs: ["tomatoes"], to: id)
        #expect(store.list(id)?.items.count == 1)
        #expect(store.list(id)?.items.first?.quantity == 3)
        #expect(store.list(id)?.items.first?.aisle == .pantry)
        #expect(store.undoActions[id] == nil)
    }

    @Test func customAisleOrderIsCompletePersistedAndUsedInSharing() throws {
        let suite = "ShoppingTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShoppingStore(defaults: defaults)
        store.setAisleOrder([.dairy, .produce, .dairy])
        #expect(store.aisleOrder.count == ShoppingAisle.allCases.count)
        #expect(Array(store.aisleOrder.prefix(2)) == [.dairy, .produce])
        #expect(ShoppingStore(defaults: defaults).aisleOrder == store.aisleOrder)
        let id = store.create(title: "Courses")
        store.addItem(name: "Citron", amount: "1", to: id)
        store.addItem(name: "Beurre", amount: "25 g", to: id)
        let list = try #require(store.list(id))
        let text = list.shareText(aisleOrder: store.aisleOrder)
        #expect(text.hasPrefix("Courses\n\nProduits frais\n☐ Beurre"))
        #expect(text.contains("Fruits & légumes\n☐ Citron"))
        defaults.set(Data("[\"unknown\"]".utf8), forKey: "petitchef.shopping.aisle-order.v1")
        #expect(ShoppingStore(defaults: defaults).aisleOrder == ShoppingAisle.allCases)
    }

    @Test func recipeFiltersIncludeSharedAndCheckedIngredientsWithTheirFullQuantities() throws {
        let suite = "ShoppingTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShoppingStore(defaults: defaults)
        let id = store.create(title: "Semaine")
        store.add(recipe: RecipeCatalog.burgerAndFries, ingredientIDs: ["tomato", "buns"], to: id)
        store.add(recipe: RecipeCatalog.tomatoToast, ingredientIDs: ["tomatoes", "garlic"], to: id)
        store.addItem(name: "Café", amount: "1 paquet", to: id)
        let list = try #require(store.list(id))
        let burger = try #require(list.recipes.first { $0.recipeID == "burger-and-oven-fries" })
        let toast = try #require(list.recipes.first { $0.recipeID == "tomato-mozzarella-toast" })
        #expect(list.items(for: nil).count == 4)
        #expect(list.items(for: burger.id).map(\.name) == ["Pains à burger", "Tomate"])
        #expect(list.items(for: toast.id).map(\.name) == ["Tomate", "Ail"])
        #expect(list.items(for: toast.id).first?.amount == "3")
        #expect(list.items(for: UUID()).isEmpty)
        let tomato = try #require(list.items.first { $0.mergeName == "tomate" })
        store.toggle(tomato.id, in: id)
        #expect(store.list(id)?.items(for: toast.id).first?.isChecked == true)
    }

}
