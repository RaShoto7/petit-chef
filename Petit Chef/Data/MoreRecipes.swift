import Foundation

nonisolated extension RecipeCatalog {
    static let lemonPasta = Recipe(
        id: "lemon-pasta", title: "Pâtes au citron", subtitle: "",
        heroImageName: "", cookingMethod: "À la casserole", servings: 2, estimatedTotalMinutes: 20,
        ingredientGroups: [
            IngredientGroup(id: "pasta", title: "Pâtes et sauce", ingredients: [
                Ingredient(id: "spaghetti", name: "Spaghetti", quantity: 200, unit: "g", detail: "Cuisson 8 min indiquée sur le paquet"),
                Ingredient(id: "lemon", name: "Citron", quantity: 1, unit: "", detail: "Non traité, zeste et jus"),
                Ingredient(id: "parmesan", name: "Parmesan", quantity: 50, unit: "g", detail: "Finement râpé"),
                Ingredient(id: "butter", name: "Beurre", quantity: 25, unit: "g", detail: nil)
            ]),
            IngredientGroup(id: "finishing", title: "Assaisonnement", ingredients: [
                Ingredient(id: "basil", name: "Basilic", quantity: 6, unit: "feuilles", detail: nil),
                Ingredient(id: "seasoning", name: "Sel & poivre", quantity: nil, unit: "", detail: "Assaisonnement")
            ])
        ],
        equipment: ["Casserole", "Grande poêle", "Râpe fine", "Tasse", "Passoire"],
        steps: [
            step("heat-water", "Chauffer l’eau", "Porter une casserole d’eau à ébullition.", active: 1),
            step("zest-lemon", "Préparer le citron", "Prélever le zeste du citron lavé. Presser une moitié et râper le parmesan.", active: 3, dependencies: ["heat-water"]),
            step("boil-pasta", "Cuire les pâtes", "Saler l’eau bouillante et ajouter les spaghetti. Le minuteur est réglé sur 8 minutes : l’ajuster à la durée indiquée sur le paquet.", active: 1, passive: 8, parallel: "Prépare la sauce pendant la cuisson.", dependencies: ["zest-lemon"], timer: RecipeTimer(id: "pasta-cook", label: "Pâtes", durationSeconds: 480)),
            step("lemon-sauce", "Préparer la sauce", "Faire fondre le beurre à feu doux avec les zestes. Ajouter de l’eau de cuisson et retirer du feu.", active: 3, startAfter: "boil-pasta"),
            step("toss-pasta", "Lier la sauce", "Réserver une tasse d’eau de cuisson. Égoutter les pâtes et mélanger hors du feu avec la sauce, le parmesan et le jus de citron. Incorporer l’eau réservée progressivement.", active: 2, dependencies: ["boil-pasta", "lemon-sauce"]),
            step("serve-pasta", "Servir", "Ajouter le basilic et servir immédiatement.", active: 1, dependencies: ["toss-pasta"])
        ],
        tip: "Garde toujours un peu d’eau de cuisson : son amidon lie la sauce. Ajoute le parmesan hors du feu pour une texture lisse."
    )

    static let tomatoToast = Recipe(
        id: "tomato-mozzarella-toast", title: "Tartines tomate & mozzarella", subtitle: "",
        heroImageName: "", cookingMethod: "Au four", servings: 2, estimatedTotalMinutes: 20,
        ingredientGroups: [
            IngredientGroup(id: "toast", title: "Tartines", ingredients: [
                Ingredient(id: "bread", name: "Pain de campagne", quantity: 4, unit: "tranches", detail: "Environ 1,5 cm d’épaisseur"),
                Ingredient(id: "tomatoes", name: "Tomates", quantity: 2, unit: "", detail: "Bien mûres"),
                Ingredient(id: "mozzarella", name: "Mozzarella", quantity: 125, unit: "g", detail: "Bien égouttée"),
                Ingredient(id: "garlic", name: "Ail", quantity: 1, unit: "gousse", detail: nil)
            ]),
            IngredientGroup(id: "seasoning", title: "Assaisonnement", ingredients: [
                Ingredient(id: "olive-oil", name: "Huile d’olive", quantity: 2, unit: "c. à soupe", detail: nil),
                Ingredient(id: "basil", name: "Basilic", quantity: 8, unit: "feuilles", detail: nil),
                Ingredient(id: "salt-pepper", name: "Sel & poivre", quantity: nil, unit: "", detail: "Assaisonnement")
            ])
        ],
        equipment: ["Four", "Plaque", "Planche", "Couteau", "Bol"],
        steps: [
            step("preheat-toast", "Préchauffer le four", "Préchauffer le four à 180 °C. Disposer le pain sur une plaque.", active: 2),
            step("slice-tomatoes", "Découper les ingrédients", "Couper les tomates en dés et la mozzarella égouttée en tranches. Couper l’ail en deux.", active: 3, dependencies: ["preheat-toast"]),
            step("build-toast", "Garnir le pain", "Frotter le pain avec l’ail. Répartir la moitié de l’huile et la mozzarella sur les tartines.", active: 2, dependencies: ["slice-tomatoes"]),
            step("bake-toast", "Gratiner les tartines", "Enfourner à 180 °C pendant 8 minutes. Vérifier que la mozzarella a fondu et que les bords du pain sont dorés.", active: 1, passive: 8, parallel: "Assaisonne les tomates pendant ce temps.", dependencies: ["build-toast"], timer: RecipeTimer(id: "toast-bake", label: "Tartines", durationSeconds: 480)),
            step("dress-tomatoes", "Assaisonner les tomates", "Mélanger les tomates avec le reste d’huile et la moitié du basilic. Assaisonner.", active: 2, startAfter: "bake-toast"),
            step("serve-toast", "Servir les tartines", "Répartir les tomates sur les tartines chaudes. Ajouter le reste du basilic et servir.", active: 1, dependencies: ["bake-toast", "dress-tomatoes"])
        ],
        tip: "Égoutte bien la mozzarella et garde les tomates pour la sortie du four : le pain restera croustillant."
    )

    private static func step(
        _ id: String, _ title: String, _ instruction: String,
        active: Int, passive: Int = 0, parallel: String? = nil,
        dependencies: [String] = [], startAfter: String? = nil, timer: RecipeTimer? = nil
    ) -> RecipeStep {
        RecipeStep(id: id, title: title, instruction: instruction,
                   activeMinutes: active, passiveMinutes: passive,
                   timingNote: nil, parallelNote: parallel,
                   dependencies: dependencies, startAfterStepID: startAfter, timer: timer)
    }
}
