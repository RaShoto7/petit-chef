import Foundation
import Testing
@testable import Petit_Chef

struct Petit_ChefTests {
    @Test func catalogSurvivesJSONRoundTrip() throws {
        let encoded = try JSONEncoder().encode(RecipeCatalog.recipes)
        let decoded = try JSONDecoder().decode([Recipe].self, from: encoded)

        #expect(decoded == RecipeCatalog.recipes)
    }

    @Test func contentHasStableUniqueIdentifiersAndUsableQuantities() {
        let recipes = RecipeCatalog.recipes
        #expect(!recipes.isEmpty)
        #expect(Set(recipes.map(\.id)).count == recipes.count)

        for recipe in recipes {
            #expect(recipe.servings > 0)
            #expect(recipe.estimatedTotalMinutes > 0)
            #expect(!recipe.steps.isEmpty)
            #expect(Set(recipe.ingredientGroups.map(\.id)).count == recipe.ingredientGroups.count)

            let ingredients = recipe.ingredientGroups.flatMap(\.ingredients)
            #expect(!ingredients.isEmpty)
            #expect(Set(ingredients.map(\.id)).count == ingredients.count)

            for ingredient in ingredients {
                #expect(!ingredient.id.isEmpty)
                #expect(!ingredient.name.isEmpty)
                if let quantity = ingredient.quantity {
                    #expect(quantity.isFinite && quantity > 0)
                } else {
                    #expect(ingredient.detail?.isEmpty == false)
                }
            }
        }
    }

    @Test func dependenciesReferenceEarlierStepsAndParallelCooking() {
        for recipe in RecipeCatalog.recipes {
            let stepsByID = Dictionary(grouping: recipe.steps, by: \.id)
            #expect(stepsByID.count == recipe.steps.count)
            var earlierIDs = Set<String>()

            for step in recipe.steps {
                #expect(!step.id.isEmpty)
                #expect(Set(step.dependencies).count == step.dependencies.count)
                // Requiring earlier references also rejects self-dependencies and cycles.
                #expect(step.dependencies.allSatisfy { earlierIDs.contains($0) })

                if let startingStepID = step.startAfterStepID {
                    #expect(earlierIDs.contains(startingStepID))
                    #expect(!step.dependencies.contains(startingStepID))
                    #expect((stepsByID[startingStepID]?.first?.passiveMinutes ?? 0) > 0)
                }
                earlierIDs.insert(step.id)
            }
        }
    }

    @Test func timersMatchPassiveCookingWithoutSummingOverlappingSteps() {
        for recipe in RecipeCatalog.recipes {
            let timers = recipe.steps.compactMap(\.timer)
            #expect(Set(timers.map(\.id)).count == timers.count)

            for step in recipe.steps {
                #expect(step.activeMinutes >= 0)
                #expect(step.passiveMinutes >= 0)
                #expect(step.estimatedMinutes > 0)

                if let timer = step.timer {
                    #expect(!timer.id.isEmpty)
                    #expect(!timer.label.isEmpty)
                    #expect(timer.durationSeconds > 0)
                    #expect(timer.durationSeconds == step.passiveMinutes * 60)
                }
            }
        }
    }
}
