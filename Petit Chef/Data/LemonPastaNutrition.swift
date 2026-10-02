import Foundation

/// Estimates for this recipe only. References and edible-weight assumptions are
/// recorded in docs/design/lemon-pasta.md; no network is used in the app.
nonisolated struct LemonPastaNutrition: Equatable, Sendable {
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double

    func divided(by servings: Int) -> Self {
        scaled(by: 1 / Double(max(1, servings)))
    }

    private func scaled(by factor: Double) -> Self {
        Self(calories: calories * factor, protein: protein * factor,
             carbohydrates: carbohydrates * factor, fat: fat * factor)
    }

    private static let perQuantity: [String: Self] = [
        // Per gram of dry pasta, parmesan and butter, respectively.
        "spaghetti": Self(calories: 3.59, protein: 0.128, carbohydrates: 0.709, fat: 0.020),
        "parmesan": Self(calories: 4.02, protein: 0.324, carbohydrates: 0, fat: 0.297),
        "butter": Self(calories: 7.44, protein: 0.008, carbohydrates: 0.006, fat: 0.820),
        // Per lemon: 30 g juice (half the fruit) + 2 g zest. USDA carbohydrates
        // exclude dietary fibre here to use the same basis as European labels.
        "lemon": Self(calories: 7.54, protein: 0.135, carbohydrates: 2.088, fat: 0.078),
        // One fresh leaf is estimated at 0.5 g. Salt/pepper are negligible.
        "basil": Self(calories: 0.115, protein: 0.01575, carbohydrates: 0.00525, fat: 0.0032)
    ]

    static func estimate(for recipe: Recipe) -> Self? {
        guard recipe.id == RecipeCatalog.lemonPasta.id, recipe.servings > 0 else { return nil }
        let originals = Dictionary(uniqueKeysWithValues: RecipeCatalog.lemonPasta.ingredientGroups
            .flatMap(\.ingredients).map { ($0.id, $0) })
        var sum = Self(calories: 0, protein: 0, carbohydrates: 0, fat: 0)
        for ingredient in recipe.ingredientGroups.flatMap(\.ingredients) {
            // An ingredient's editable name or unit can change its identity.
            // Suppress an incomplete estimate after substitutions or additions.
            guard let original = originals[ingredient.id],
                  ingredient.name == original.name, ingredient.unit == original.unit else { return nil }
            if ingredient.id == "seasoning" { continue }
            guard let reference = perQuantity[ingredient.id], let amount = ingredient.quantity,
                  amount.isFinite, amount >= 0 else { return nil }
            let contribution = reference.scaled(by: amount)
            sum = Self(calories: sum.calories + contribution.calories,
                       protein: sum.protein + contribution.protein,
                       carbohydrates: sum.carbohydrates + contribution.carbohydrates,
                       fat: sum.fat + contribution.fat)
        }
        return sum
    }
}
