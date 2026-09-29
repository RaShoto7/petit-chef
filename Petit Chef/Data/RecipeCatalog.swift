import Foundation

nonisolated enum RecipeCatalog {
    static let recipes: [Recipe] = [burgerAndFries, lemonPasta, tomatoToast]

    static let burgerAndFries = Recipe(
        id: "burger-and-oven-fries",
        title: "Burger & frites",
        subtitle: "",
        heroImageName: "BurgerHero",
        cookingMethod: "Au four",
        servings: 2,
        estimatedTotalMinutes: 50,
        ingredientGroups: [
            IngredientGroup(
                id: "fries",
                title: "Pour les frites",
                ingredients: [
                    Ingredient(id: "potatoes", name: "Pommes de terre", quantity: 600, unit: "g", detail: "Chair farineuse, type Bintje ou Agria"),
                    Ingredient(id: "oil", name: "Huile neutre", quantity: 2, unit: "c. à soupe", detail: "Et un filet pour la poêle")
                ]
            ),
            IngredientGroup(
                id: "burgers",
                title: "Pour les burgers",
                ingredients: [
                    Ingredient(id: "buns", name: "Pains à burger", quantity: 2, unit: "", detail: nil),
                    Ingredient(id: "beef", name: "Steaks hachés de bœuf", quantity: 2, unit: "× 125 g", detail: "125 g chacun, frais ou décongelés au réfrigérateur"),
                    Ingredient(id: "cheddar", name: "Cheddar", quantity: 2, unit: "tranches", detail: nil),
                    Ingredient(id: "lettuce", name: "Salade", quantity: 2, unit: "feuilles", detail: nil),
                    Ingredient(id: "tomato", name: "Tomate", quantity: 1, unit: "", detail: nil),
                    Ingredient(id: "onion", name: "Oignon", quantity: 0.5, unit: "", detail: nil),
                    Ingredient(id: "sauce", name: "Sauce au choix", quantity: 2, unit: "c. à soupe", detail: nil),
                    Ingredient(id: "seasoning", name: "Sel & poivre", quantity: nil, unit: "", detail: "Assaisonnement")
                ]
            )
        ],
        equipment: ["Four", "Grande plaque", "Poêle", "Couteau & planche", "Torchon propre", "Sonde de cuisson"],
        steps: [
            RecipeStep(
                id: "preheat-and-wash",
                title: "Préchauffer le four",
                instruction: "Préchauffer le four à 230 °C en chaleur traditionnelle. Laver les pommes de terre.",
                activeMinutes: 3,
                passiveMinutes: 0,
                timingNote: nil,
                parallelNote: "Le four chauffe pendant que tu prépares les frites.",
                dependencies: [],
                startAfterStepID: nil,
                timer: nil
            ),
            RecipeStep(
                id: "cut-fries",
                title: "Couper les frites",
                instruction: "Tailler des bâtonnets réguliers d’environ 1 cm d’épaisseur.",
                activeMinutes: 5,
                passiveMinutes: 0,
                timingNote: nil,
                parallelNote: nil,
                dependencies: ["preheat-and-wash"],
                startAfterStepID: nil,
                timer: nil
            ),
            RecipeStep(
                id: "dry-fries",
                title: "Rincer et sécher",
                instruction: "Rincer les bâtonnets à l’eau froide. Les égoutter, puis les sécher soigneusement dans un torchon propre.",
                activeMinutes: 3,
                passiveMinutes: 0,
                timingNote: nil,
                parallelNote: nil,
                dependencies: ["cut-fries"],
                startAfterStepID: nil,
                timer: nil
            ),
            RecipeStep(
                id: "bake-fries",
                title: "Enfourner les frites",
                instruction: "Enrober les frites d’huile. Les répartir sur une plaque en une seule couche. Enfourner à 230 °C pour 15 minutes.",
                activeMinutes: 2,
                passiveMinutes: 15,
                timingNote: "15 min de cuisson avant de les retourner.",
                parallelNote: "Pendant ce temps, prépare la garniture des burgers.",
                dependencies: ["dry-fries"],
                startAfterStepID: nil,
                timer: RecipeTimer(id: "fries-first-bake", label: "Frites · première cuisson", durationSeconds: 900)
            ),
            RecipeStep(
                id: "prepare-toppings",
                title: "Préparer la garniture",
                instruction: "Laver la salade. Émincer la tomate et l’oignon. Garder la viande au réfrigérateur jusqu’à la cuisson.",
                activeMinutes: 7,
                passiveMinutes: 0,
                timingNote: "Une fois prêt, attends la fin des 15 min de cuisson des frites.",
                parallelNote: "Les frites cuisent pendant que tu t'occupes du reste.",
                dependencies: [],
                startAfterStepID: "bake-fries",
                timer: nil
            ),
            RecipeStep(
                id: "finish-fries",
                title: "Retourner les frites",
                instruction: "Retourner les frites et poursuivre 15 minutes à 230 °C. Vérifier qu’elles sont dorées et tendres à cœur.",
                activeMinutes: 1,
                passiveMinutes: 15,
                timingNote: "Environ 30 min de four au total, selon leur épaisseur et ton four.",
                parallelNote: "Lance maintenant les steaks pour que tout arrive chaud.",
                dependencies: ["bake-fries"],
                startAfterStepID: nil,
                timer: RecipeTimer(id: "fries-final-bake", label: "Frites · finition", durationSeconds: 900)
            ),
            RecipeStep(
                id: "cook-beef",
                title: "Cuire les steaks",
                instruction: "Saisir les steaks dans une poêle huilée. Atteindre 70 °C à cœur pendant 2 minutes, vérifiés à la sonde. Ajouter le cheddar et couvrir brièvement.",
                activeMinutes: 10,
                passiveMinutes: 0,
                timingNote: "Durée indicative : l'épaisseur et la poêle changent le temps de cuisson. Utilise une assiette propre pour la viande cuite.",
                parallelNote: "Les frites terminent de dorer au four.",
                dependencies: ["prepare-toppings"],
                startAfterStepID: "finish-fries",
                timer: nil
            ),
            RecipeStep(
                id: "toast-buns",
                title: "Toaster les pains",
                instruction: "Placer les pains ouverts au four, mie vers le haut, pendant 1 à 2 minutes. Surveiller la coloration.",
                activeMinutes: 2,
                passiveMinutes: 0,
                timingNote: "Garde les steaks au chaud, couverts, le temps de toaster les pains.",
                parallelNote: nil,
                dependencies: ["cook-beef"],
                startAfterStepID: nil,
                timer: nil
            ),
            RecipeStep(
                id: "assemble-and-serve",
                title: "Assembler les burgers",
                instruction: "Répartir la sauce et la garniture dans les pains. Ajouter les steaks au cheddar. Servir avec les frites.",
                activeMinutes: 3,
                passiveMinutes: 0,
                timingNote: nil,
                parallelNote: nil,
                dependencies: ["finish-fries", "toast-buns"],
                startAfterStepID: nil,
                timer: nil
            )
        ],
        tip: "Le secret des frites dorées : bien les sécher et leur laisser de la place sur la plaque. Les 50 minutes sont un repère, ajuste la cuisson à ton four."
    )
}
