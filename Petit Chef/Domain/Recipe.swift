import Foundation

/// Curated content, independent from the UI and from any future language model.
/// The total is an editorial estimate, not the sum of overlapping step durations.
nonisolated struct Recipe: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let heroImageName: String
    let cookingMethod: String
    var servings: Int
    let estimatedTotalMinutes: Int
    var ingredientGroups: [IngredientGroup]
    let equipment: [String]
    let steps: [RecipeStep]
    let tip: String
}

nonisolated struct IngredientGroup: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    var ingredients: [Ingredient]
}

nonisolated struct Ingredient: Codable, Sendable, Equatable, Identifiable {
    let id: String
    var name: String
    var quantity: Double?
    var unit: String
    let detail: String?
}

nonisolated struct RecipeStep: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let instruction: String
    let activeMinutes: Int
    let passiveMinutes: Int
    let timingNote: String?
    let parallelNote: String?

    /// These steps must be finished before this one can begin.
    let dependencies: [String]

    /// This step can begin once the referenced step's passive cooking has started.
    /// This is distinct from waiting for that cooking to finish.
    let startAfterStepID: String?
    let timer: RecipeTimer?

    var estimatedMinutes: Int { activeMinutes + passiveMinutes }
}

/// A reminder to check food, never a guarantee that food is cooked.
nonisolated struct RecipeTimer: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let label: String
    let durationSeconds: Int
}
