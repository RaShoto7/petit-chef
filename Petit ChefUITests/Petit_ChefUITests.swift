import XCTest
import UIKit

final class Petit_ChefUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testLemonPastaNutritionIsReadableWithoutScrolling() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-cooking"]
        app.launch()
        let pasta = app.buttons["home.recipe.lemon-pasta"]
        XCTAssertTrue(pasta.waitForExistence(timeout: 8))
        pasta.tap()
        let scope = app.segmentedControls["recipe.nutrition.scope"]
        XCTAssertTrue(scope.waitForExistence(timeout: 4))
        let start = app.buttons["recipe.start"]
        for name in ["protein", "carbohydrates", "fat"] {
            let metric = app.descendants(matching: .any)["recipe.nutrition." + name].firstMatch
            XCTAssertTrue(metric.exists)
            XCTAssertTrue(metric.isHittable)
            XCTAssertLessThan(metric.frame.maxY, start.frame.minY)
        }
        screenshot(app, "L00 — Recette et nutrition")
        scope.buttons["Par personne"].tap()
        XCTAssertEqual(app.staticTexts["recipe.nutrition.calories"].label, "557")
        screenshot(app, "L00b — Nutrition par personne")
    }

    @MainActor
    func testLemonPastaNutritionAndGuidedCooking() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-cooking"]
        app.launch()
        let pasta = app.buttons["home.recipe.lemon-pasta"]
        XCTAssertTrue(pasta.waitForExistence(timeout: 8))
        pasta.tap()
        let scope = app.segmentedControls["recipe.nutrition.scope"]
        XCTAssertTrue(scope.waitForExistence(timeout: 4))
        XCTAssertTrue(scope.buttons["Pour 2 pers."].isSelected)
        XCTAssertEqual(app.staticTexts["recipe.nutrition.calories"].label, "1 113")
        app.buttons["recipe.servings.plus"].tap()
        XCTAssertEqual(app.staticTexts["recipe.servings.value"].label, "3 pers.")
        XCTAssertTrue(scope.buttons["Pour 3 pers."].isSelected)
        XCTAssertEqual(app.staticTexts["recipe.nutrition.calories"].label, "1 670")
        scope.buttons["Par personne"].tap()
        XCTAssertEqual(app.staticTexts["recipe.nutrition.calories"].label, "557")
        app.buttons["recipe.servings.minus"].tap()
        XCTAssertEqual(app.staticTexts["recipe.nutrition.calories"].label, "557")
        scope.buttons["Pour 2 pers."].tap()
        app.swipeUp()
        screenshot(app, "L01 — Calories et macros pour deux")
        XCTAssertTrue(app.staticTexts["ingredient.quantity.spaghetti"].exists)
        app.buttons["recipe.start"].tap()
        assertStep(app, "Chauffer l’eau")
        Thread.sleep(forTimeInterval: 3)
        screenshot(app, "L02 — Eau à ébullition")
        next(app, "Préparer le citron")
        Thread.sleep(forTimeInterval: 4)
        screenshot(app, "L03 — Zester le citron")
        next(app, "Cuire les pâtes")
        Thread.sleep(forTimeInterval: 4)
        screenshot(app, "L04 — Plonger les spaghetti")
        next(app, "Préparer la sauce")
        XCTAssertTrue(app.staticTexts["Pâtes"].exists)
        Thread.sleep(forTimeInterval: 6)
        screenshot(app, "L05 — Sauce au citron")
        // Reading the next step never cancels the real pasta timer.
        next(app, "Lier la sauce")
        XCTAssertTrue(app.buttons["cooking.timer.stop"].exists)
        app.buttons["cooking.previous"].tap()
        assertStep(app, "Préparer la sauce")
        next(app, "Lier la sauce")
        Thread.sleep(forTimeInterval: 6)
        screenshot(app, "L06 — Lier hors du feu")
        app.buttons["cooking.timer.stop"].firstMatch.tap()
        XCTAssertFalse(app.buttons["cooking.timer.stop"].exists)
        next(app, "Servir")
        Thread.sleep(forTimeInterval: 6)
        screenshot(app, "L07 — Basilic et dressage")
        app.buttons["cooking.next"].tap()
        XCTAssertTrue(app.buttons["cooking.finish"].waitForExistence(timeout: 5))
        app.buttons["cooking.finish"].tap()
        XCTAssertTrue(pasta.waitForExistence(timeout: 5))
    }

    @MainActor
    func testCustomRecipeAndFlexibleCookingSurviveRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-cooking"]
        app.launch()
        let recipe = app.buttons["home.recipe.burger-and-oven-fries"]
        XCTAssertTrue(recipe.waitForExistence(timeout: 8))
        XCTAssertEqual(app.tabBars.count, 0)
        XCTAssertEqual(app.staticTexts["home.title"].label, "mes recettes.")
        screenshot(app, "01 — Mes recettes")
        recipe.tap()
        XCTAssertTrue(app.staticTexts["recipe.title"].waitForExistence(timeout: 4))
        screenshot(app, "02 — Recette")
        app.buttons["recipe.servings.plus"].tap()
        XCTAssertEqual(app.staticTexts["recipe.servings.value"].label, "3 pers.")
        XCTAssertEqual(app.staticTexts["ingredient.quantity.potatoes"].label, "900 g")
        app.buttons["recipe.ingredients.edit"].tap()
        app.buttons["ingredients.row.potatoes"].tap()
        let name = app.textFields["ingredients.name.potatoes"]
        XCTAssertTrue(name.waitForExistence(timeout: 4))
        name.tap()
        name.press(forDuration: 1.2)
        if app.menuItems["Tout sélectionner"].waitForExistence(timeout: 1) { app.menuItems["Tout sélectionner"].tap() }
        // Update via the standard text field; retain the original ingredient's stable identity.
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 40) + "Pommes de terre Agria")
        screenshot(app, "03 — Ingrédient ciblé")
        app.buttons["ingredients.apply"].tap()
        app.buttons["ingredients.undo"].tap()
        XCTAssertTrue(app.buttons["ingredients.row.potatoes"].label.contains("Pommes de terre"))
        XCTAssertFalse(app.buttons["ingredients.row.potatoes"].label.contains("Agria"))
        app.buttons["ingredients.redo"].tap()
        XCTAssertTrue(app.buttons["ingredients.row.potatoes"].label.contains("Agria"))
        screenshot(app, "03b — Liste des ingrédients")
        app.buttons["ingredients.save"].tap()
        app.buttons["recipe.start"].tap()
        assertStep(app, "Préchauffer le four")
        screenshot(app, "04 — Préchauffage")
        next(app, "Couper les frites")
        screenshot(app, "05 — Découpe")
        app.buttons["cooking.previous"].tap()
        assertStep(app, "Préchauffer le four")
        next(app, "Couper les frites")
        next(app, "Rincer et sécher")
        next(app, "Enfourner les frites")
        next(app, "Préparer la garniture")
        XCTAssertTrue(app.staticTexts["Frites · première cuisson"].exists)
        next(app, "Retourner les frites")
        // The countdown does not block reading or preparing a later step.
        app.buttons["cooking.next"].press(forDuration: 0.8)
        app.buttons["cooking.skip"].tap()
        assertStep(app, "Cuire les steaks")
        screenshot(app, "06 — Navigation pendant la cuisson")
        app.buttons["cooking.previous"].tap()
        assertStep(app, "Retourner les frites")
        app.buttons["cooking.timer.options"].firstMatch.tap()
        app.buttons["Retirer 1 minute"].tap()
        let timer = app.buttons["cooking.timer.edit"].firstMatch
        XCTAssertTrue(timer.exists)
        let before = timer.value as? String ?? ""
        XCTAssertTrue(before.hasPrefix("13:") || before.hasPrefix("14:"))
        timer.tap()
        let wheels = app.pickerWheels
        XCTAssertEqual(wheels.count, 3)
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "0")
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: "5")
        wheels.element(boundBy: 2).adjust(toPickerWheelValue: "30")
        screenshot(app, "06b — Réglage du minuteur")
        app.buttons["timer.apply"].tap()
        XCTAssertTrue((timer.value as? String ?? "").hasPrefix("05:"))
        app.buttons["cooking.minimize"].tap()
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["home.resume"].waitForExistence(timeout: 6))
        app.buttons["home.resume"].tap()
        XCTAssertTrue(app.staticTexts["Frites · première cuisson"].waitForExistence(timeout: 4))
        screenshot(app, "07 — Minuteur restauré")
        app.buttons["cooking.timer.stop"].firstMatch.tap()
        XCTAssertEqual(app.sheets.count, 0)
        XCTAssertFalse(app.buttons["cooking.timer.stop"].exists)
        XCTAssertFalse(app.staticTexts["Frites · première cuisson"].exists)
        app.buttons["cooking.minimize"].tap()
        app.buttons["home.account"].tap()
        XCTAssertTrue(app.buttons["settings.signInWithApple"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["settings.signInWithApple"].isHittable)
        XCTAssertFalse(app.switches["settings.chefTips"].exists)
        screenshot(app, "08 — Profil et réglages")
        app.buttons["settings.close"].tap()
        recipe.tap()
        XCTAssertEqual(app.staticTexts["recipe.servings.value"].label, "3 pers.")
        XCTAssertTrue(app.staticTexts["Pommes de terre Agria"].exists)
    }

    @MainActor
    func testIngredientAdditionAndRemoval() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-cooking"]
        app.launch()
        app.buttons["home.recipe.burger-and-oven-fries"].tap()
        app.buttons["recipe.ingredients.edit"].tap()
        let add = app.buttons["ingredients.add"]
        for _ in 0..<6 where !add.isHittable { app.swipeUp() }
        XCTAssertTrue(add.isHittable)
        add.tap()
        let name = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH 'ingredients.name.custom-'")).firstMatch
        for _ in 0..<3 where !name.isHittable { app.swipeUp() }
        XCTAssertTrue(name.isHittable)
        name.tap()
        name.typeText("Cornichons")
        app.buttons["ingredients.apply"].tap()
        app.buttons["ingredients.save"].tap()
        XCTAssertTrue(app.staticTexts["Cornichons"].exists)
        app.buttons["recipe.ingredients.edit"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'ingredients.row.custom-'")).firstMatch
        for _ in 0..<6 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.isHittable)
        row.tap()
        app.buttons["ingredients.delete"].tap()
        XCTAssertTrue(app.buttons["ingredients.save"].isEnabled)
        app.buttons["ingredients.save"].tap()
        XCTAssertFalse(app.staticTexts["Cornichons"].exists)
        XCTAssertTrue(app.staticTexts["Pommes de terre"].exists)
    }

    @MainActor
    func testRecipeIllustrationsRemainVisibleAfterTheirEntrance() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-cooking"]
        app.launch()
        let burger = app.buttons["home.recipe.burger-and-oven-fries"]
        XCTAssertTrue(burger.waitForExistence(timeout: 8))
        for id in ["burger-and-oven-fries", "lemon-pasta", "tomato-mozzarella-toast"] {
            let card = app.buttons["home.recipe.\(id)"]
            // Check rendered pixels, not just the presence of an Image view: a shader can hide it.
            XCTAssertGreaterThan(try coloredFraction(card.screenshot().image), 0.025, "Illustration invisible : \(id)")
        }
        screenshot(app, "01 — Mes recettes")
        burger.tap()
        XCTAssertTrue(app.staticTexts["recipe.title"].waitForExistence(timeout: 4))
        screenshot(app, "02 — Recette")
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Allergènes"].exists)
        XCTAssertFalse(app.staticTexts["Références de la recette"].exists)
        screenshot(app, "10 — Allergènes")
    }

    @MainActor
    func testToastDisclosuresNavigationAndCompletion() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-cooking"]
        app.launch()
        let toast = app.buttons["home.recipe.tomato-mozzarella-toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 8))
        screenshot(app, "T00 — Accueil italique")
        toast.tap()
        XCTAssertTrue(app.staticTexts["recipe.title"].waitForExistence(timeout: 4))
        screenshot(app, "T01 — Tartines")
        let steps = app.buttons["recipe.disclosure.steps"]
        for _ in 0..<5 where !steps.isHittable { app.swipeUp() }
        let equipment = app.buttons["recipe.disclosure.equipment"]
        for _ in 0..<3 {
            steps.tap()
            XCTAssertEqual(steps.value as? String, "Déplié")
            XCTAssertTrue(app.staticTexts["Préchauffer le four"].exists)
            steps.tap()
            XCTAssertEqual(steps.value as? String, "Replié")
            for _ in 0..<3 where !equipment.isHittable { app.swipeUp() }
            equipment.tap()
            XCTAssertEqual(equipment.value as? String, "Déplié")
            equipment.tap()
            XCTAssertEqual(equipment.value as? String, "Replié")
        }
        screenshot(app, "T02 — Verre et sections")
        app.buttons["recipe.start"].tap()
        assertStep(app, "Préchauffer le four")
        XCTAssertFalse(app.buttons["cooking.previous"].exists)
        XCTAssertFalse(app.buttons["cooking.overview"].exists)
        XCTAssertFalse(app.buttons["cooking.replay"].exists)
        Thread.sleep(forTimeInterval: 3) // Capture the gesture after arrival.
        screenshot(app, "T03 — Préchauffage Blender")
        next(app, "Découper les ingrédients")
        Thread.sleep(forTimeInterval: 5) // Capture the gesture after arrival.
        screenshot(app, "T04 — Découpe Blender")
        app.buttons["cooking.previous"].tap()
        assertStep(app, "Préchauffer le four")
        XCTAssertFalse(app.buttons["cooking.previous"].exists)
        next(app, "Découper les ingrédients")
        next(app, "Garnir le pain")
        Thread.sleep(forTimeInterval: 8) // Capture the gesture after arrival.
        screenshot(app, "T05 — Garniture Blender")
        next(app, "Gratiner les tartines")
        Thread.sleep(forTimeInterval: 7) // Capture the gesture after arrival.
        screenshot(app, "T06 — Gratinage Blender")
        next(app, "Assaisonner les tomates")
        Thread.sleep(forTimeInterval: 4) // Capture the gesture after arrival.
        screenshot(app, "T07 — Mélange Blender")
        let timer = app.buttons["cooking.timer.edit"]
        XCTAssertTrue(timer.isHittable)
        XCTAssertGreaterThan(timer.frame.midY, app.staticTexts["cooking.step.title"].frame.maxY)
        XCTAssertLessThan(timer.frame.maxY, app.buttons["cooking.next"].frame.minY)
        app.buttons["cooking.timer.stop"].firstMatch.tap()
        XCTAssertEqual(app.sheets.count, 0)
        XCTAssertFalse(app.buttons["cooking.timer.stop"].exists)
        next(app, "Servir les tartines")
        Thread.sleep(forTimeInterval: 7) // Capture the gesture after arrival.
        screenshot(app, "T08 — Dressage Blender")
        XCTAssertFalse(app.buttons["cooking.skip"].exists)
        app.buttons["cooking.next"].tap()
        XCTAssertTrue(app.buttons["cooking.finish"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["cooking.options"].exists)
        XCTAssertFalse(app.buttons["cooking.minimize"].exists)
        screenshot(app, "T09 — Fin épurée")
        let finish = app.buttons["cooking.finish"]
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: finish)
        waitForExpectations(timeout: 4)
        XCTAssertEqual(finish.label, "Terminer")
        finish.tap()
        XCTAssertTrue(app.staticTexts["home.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(toast.isHittable)
        XCTAssertFalse(app.staticTexts["recipe.title"].exists)
        XCTAssertFalse(app.buttons["home.resume"].exists)
    }

    private func coloredFraction(_ image: UIImage) throws -> Double {
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let count: Int = try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            let values = bytes.bindMemory(to: UInt8.self)
            var colored = 0
            for index in stride(from: 0, to: values.count, by: 4) {
                let channels = [Int(values[index]), Int(values[index + 1]), Int(values[index + 2])]
                if channels.max()! - channels.min()! > 35 { colored += 1 }
            }
            return colored
        }
        return Double(count) / Double(width * height)
    }

    @MainActor
    func testSystemTimerAuthorizationAndBackground() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-cooking", "-system-alarm-testing"]
        app.launch()
        app.buttons["home.recipe.burger-and-oven-fries"].tap()
        app.buttons["recipe.start"].tap()
        assertStep(app, "Préchauffer le four")
        next(app, "Couper les frites")
        next(app, "Rincer et sécher")
        next(app, "Enfourner les frites")
        next(app, "Préparer la garniture")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let permission = springboard.alerts.firstMatch
        if permission.waitForExistence(timeout: 5) {
            let allow = permission.buttons.matching(NSPredicate(format: "label == 'Allow' OR label == 'Autoriser' OR label == 'OK'")).firstMatch
            XCTAssertTrue(allow.exists, springboard.debugDescription)
            allow.tap()
        }
        if app.images["cooking.timer.muted"].exists {
            app.buttons["cooking.options"].tap()
            app.buttons["Arrêter la recette"].tap()
            app.buttons["Arrêter et annuler les minuteurs"].tap()
            throw XCTSkip("AlarmKit non autorisé par le simulateur ; activité système à vérifier sur un appareil autorisé.")
        }
        // Foreground -> background renders the system-managed countdown, not an in-app mock.
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(springboard.wait(for: .runningForeground, timeout: 5))
        _ = springboard.icons.firstMatch.waitForExistence(timeout: 5)
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "09 — Dynamic Island système"
        capture.lifetime = .keepAlways
        add(capture)
        print("SYSTEM ISLAND STATE: \(springboard.debugDescription)")
        app.activate()
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'n’a pas pu être programmé'")).firstMatch.exists)
        app.buttons["cooking.options"].tap()
        app.buttons["Arrêter la recette"].tap()
        app.buttons["Arrêter et annuler les minuteurs"].tap()
    }

    @MainActor private func next(_ app: XCUIApplication, _ title: String) {
        let button = app.buttons["cooking.next"]
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: button)
        waitForExpectations(timeout: 4)
        button.tap()
        assertStep(app, title)
    }

    @MainActor private func assertStep(_ app: XCUIApplication, _ title: String) {
        let label = app.staticTexts["cooking.step.title"]
        expectation(for: NSPredicate(format: "label == %@", title), evaluatedWith: label)
        waitForExpectations(timeout: 5)
    }

    @MainActor private func screenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
