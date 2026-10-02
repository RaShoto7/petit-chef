import Foundation
import Testing
import AVFoundation
import UIKit
import CoreMedia
@testable import Petit_Chef

struct LemonPastaTests {
    @Test func estimateUsesDryIngredientWeights() throws {
        let total = try #require(LemonPastaNutrition.estimate(for: RecipeCatalog.lemonPasta))
        #expect(abs(total.calories - 1113.23) < 0.001)
        #expect(abs(total.protein - 42.2295) < 0.001)
        #expect(abs(total.carbohydrates - 144.0695) < 0.001)
        #expect(abs(total.fat - 39.4472) < 0.001)
        let person = total.divided(by: 2)
        #expect(abs(person.calories - 556.615) < 0.001)
    }

    @Test(arguments: 1...12)
    func nutritionScalesWithServingsAndKeepsTheSamePortion(count: Int) throws {
        let original = RecipeCatalog.lemonPasta
        var draft = RecipeCustomization(recipe: original)
        draft.resize(to: count)
        var recipe = original
        recipe.servings = draft.servings
        recipe.ingredientGroups = draft.groups
        let total = try #require(LemonPastaNutrition.estimate(for: recipe))
        let reference = try #require(LemonPastaNutrition.estimate(for: original))
        let ratio = Double(count) / 2
        #expect(abs(total.calories - reference.calories * ratio) < 0.001)
        #expect(abs(total.protein - reference.protein * ratio) < 0.001)
        #expect(abs(total.carbohydrates - reference.carbohydrates * ratio) < 0.001)
        #expect(abs(total.fat - reference.fat * ratio) < 0.001)
        #expect(abs(total.divided(by: count).calories - reference.divided(by: 2).calories) < 0.001)
        #expect(recipe.steps == original.steps)
    }

    @MainActor @Test func nutritionReflectsSavedQuantityEditsAndIngredientRemoval() throws {
        let suite = "LemonPastaTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let library = RecipeLibrary(defaults: defaults)
        let original = RecipeCatalog.lemonPasta
        let base = try #require(LemonPastaNutrition.estimate(for: original))
        var draft = library.draft(for: original)
        draft.groups[0].ingredients.firstIndex { $0.id == "butter" }.map { draft.groups[0].ingredients[$0].quantity = 50 }
        library.save(draft, for: original.id)
        let restored = RecipeLibrary(defaults: defaults).recipe(from: original)
        let moreButter = try #require(LemonPastaNutrition.estimate(for: restored))
        #expect(abs(moreButter.calories - base.calories - 186) < 0.001)
        #expect(abs(moreButter.fat - base.fat - 20.5) < 0.001)
        draft.groups[0].ingredients.removeAll { $0.id == "parmesan" }
        library.save(draft, for: original.id)
        let withoutCheese = try #require(LemonPastaNutrition.estimate(for: library.recipe(from: original)))
        #expect(abs(withoutCheese.calories - moreButter.calories + 201) < 0.001)
    }

    @Test func substitutionsAndUnknownIngredientsDoNotDisplayMisleadingTotals() {
        var recipe = RecipeCatalog.lemonPasta
        recipe.ingredientGroups[0].ingredients[0].name = "Pâtes de lentilles"
        #expect(LemonPastaNutrition.estimate(for: recipe) == nil)
        recipe = RecipeCatalog.lemonPasta
        recipe.ingredientGroups[0].ingredients[0].unit = "tasses"
        #expect(LemonPastaNutrition.estimate(for: recipe) == nil)
        recipe = RecipeCatalog.lemonPasta
        recipe.ingredientGroups[0].ingredients.append(Ingredient(id: "oil", name: "Huile", quantity: 1, unit: "c. à soupe", detail: nil))
        #expect(LemonPastaNutrition.estimate(for: recipe) == nil)
        #expect(LemonPastaNutrition.estimate(for: RecipeCatalog.tomatoToast) == nil)
        #expect(LemonPastaNutrition.estimate(for: RecipeCatalog.burgerAndFries) == nil)
    }

    @Test func everyPastaStepHasItsOwnPreparedScene() {
        #expect(Set(RecipeCatalog.lemonPasta.steps.map(\.id)) == Set(AuthoredPastaScene.allCases.map(\.rawValue)))
    }

    @Test(arguments: AuthoredPastaScene.allCases)
    func pastaScenesHavePlayableAlphaMoviesAndReducedMotionStills(scene: AuthoredPastaScene) async throws {
        let url = try #require(Bundle.main.url(forResource: scene.movieName, withExtension: "mov"))
        let asset = AVURLAsset(url: url)
        #expect(try await asset.load(.isPlayable))
        #expect(abs(try await asset.load(.duration).seconds - scene.duration) < 0.05)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try #require(tracks.first)
        let formats = try await track.load(.formatDescriptions)
        let format = try #require(formats.first)
        let extensions = try #require(CMFormatDescriptionGetExtensions(format)) as NSDictionary
        #expect(extensions[kCMFormatDescriptionExtension_ContainsAlphaChannel] as? Bool == true)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero; generator.requestedTimeToleranceAfter = .zero
        for seconds in [0, scene.duration - 1.0 / 24] {
            let (image, _) = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 24))
            #expect(image.width == 840 && image.height == 640)
        }
        for suffix in ["start", "poster"] {
            let url = try #require(Bundle.main.url(forResource: "\(scene.movieName)-\(suffix)", withExtension: "png"))
            #expect(UIImage(contentsOfFile: url.path) != nil)
        }
    }
}
