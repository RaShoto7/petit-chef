import Foundation
import Observation

/// Quantities are stored numerically, including edits. Changing servings never changes cooking time.
nonisolated struct RecipeCustomization: Codable, Equatable {
    var servings: Int
    var groups: [IngredientGroup]

    init(recipe: Recipe) {
        servings = recipe.servings
        groups = recipe.ingredientGroups
    }

    mutating func resize(to count: Int) {
        guard (1...12).contains(count), servings > 0 else { return }
        let ratio = Double(count) / Double(servings)
        for group in groups.indices {
            for ingredient in groups[group].ingredients.indices {
                if let quantity = groups[group].ingredients[ingredient].quantity {
                    groups[group].ingredients[ingredient].quantity = quantity * ratio
                }
            }
        }
        servings = count
    }

    var isValid: Bool {
        (1...12).contains(servings) && !groups.flatMap(\.ingredients).isEmpty &&
        groups.flatMap(\.ingredients).allSatisfy {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            ($0.quantity.map { $0.isFinite && $0 > 0 && $0 <= 100_000 } ?? true)
        }
    }
}

@MainActor @Observable
final class RecipeLibrary {
    private var customizations: [String: RecipeCustomization]
    @ObservationIgnored private let defaults: UserDefaults
    private let key = "petitchef.recipe.customizations.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key), let decoded = try? JSONDecoder().decode([String: RecipeCustomization].self, from: data) {
            customizations = decoded.filter { $0.value.isValid }
        } else { customizations = [:] }
    }

    func draft(for recipe: Recipe) -> RecipeCustomization {
        customizations[recipe.id] ?? RecipeCustomization(recipe: recipe)
    }

    func recipe(from original: Recipe) -> Recipe {
        let draft = draft(for: original)
        var result = original
        result.servings = draft.servings
        result.ingredientGroups = draft.groups
        return result
    }

    func save(_ draft: RecipeCustomization, for recipeID: String) {
        guard draft.isValid else { return }
        customizations[recipeID] = draft
        persist()
    }

    func resize(_ original: Recipe, to count: Int) {
        var value = draft(for: original)
        value.resize(to: count)
        save(value, for: original.id)
    }

    func reset(_ recipeID: String) {
        customizations.removeValue(forKey: recipeID)
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(customizations) { defaults.set(data, forKey: key) }
    }
}

nonisolated enum IngredientFormatting {
    static func quantity(_ ingredient: Ingredient) -> String {
        guard let value = ingredient.quantity else { return "—" }
        let number = value.formatted(.number.locale(Locale(identifier: "fr_FR")).precision(.fractionLength(0...2)))
        return ingredient.unit.isEmpty ? number : "\(number) \(ingredient.unit)"
    }
}
