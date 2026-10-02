import SwiftUI

struct LemonPastaNutritionCard: View {
    let recipe: Recipe
    @State private var perPerson = false

    private var estimate: LemonPastaNutrition? { LemonPastaNutrition.estimate(for: recipe) }
    private var shown: LemonPastaNutrition? {
        perPerson ? estimate?.divided(by: recipe.servings) : estimate
    }

    var body: some View {
        ChefCard(tint: DesignSystem.Colors.sand) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Calories & macros")
                    .font(DesignSystem.Typography.label)
                    .accessibilityAddTraits(.isHeader)
                if let shown {
                    Picker("Quantité affichée", selection: $perPerson) {
                        Text("Par personne").tag(true)
                        Text("Pour \(recipe.servings) pers.").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("recipe.nutrition.scope")
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(shown.calories.formatted(.number.locale(Locale(identifier: "fr_FR"))
                            .precision(.fractionLength(0))))
                            .font(.system(.largeTitle, design: .rounded, weight: .medium))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .accessibilityIdentifier("recipe.nutrition.calories")
                        Text("kcal").font(.subheadline).foregroundStyle(DesignSystem.Colors.secondaryInk)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        metric("Protéines", value: shown.protein, id: "protein")
                        metric("Glucides", value: shown.carbohydrates, id: "carbohydrates")
                        metric("Lipides", value: shown.fat, id: "fat")
                    }
                    Text("Valeurs estimées, selon les produits.")
                        .font(.caption).foregroundStyle(DesignSystem.Colors.secondaryInk)
                } else {
                    Text("Estimation indisponible pour les ingrédients remplacés ou ajoutés.")
                        .font(.subheadline).foregroundStyle(DesignSystem.Colors.secondaryInk)
                        .accessibilityIdentifier("recipe.nutrition.unavailable")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metric(_ label: String, value: Double, id: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value.formatted(.number.locale(Locale(identifier: "fr_FR"))
                .precision(.fractionLength(0...1))) + " g")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())
            Text(label).font(.caption).foregroundStyle(DesignSystem.Colors.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recipe.nutrition.\(id)")
    }
}
