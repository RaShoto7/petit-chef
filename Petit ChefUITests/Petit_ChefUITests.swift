import XCTest
import UIKit

final class Petit_ChefUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testShoppingExportCheckAndRestore() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-cooking"]
        app.launch()
        app.tabBars.buttons["Listes"].tap()
        XCTAssertTrue(app.staticTexts["Aucune liste"].waitForExistence(timeout: 5))
        screenshot(app, "Shopping — Empty")
        app.tabBars.buttons["Recettes"].tap()
        app.buttons["home.recipe.burger-and-oven-fries"].tap()
        app.buttons["recipe.servings.plus"].tap()
        let export = app.buttons["recipe.shopping"]
        for _ in 0..<5 where !export.isHittable { app.swipeUp() }
        XCTAssertTrue(export.isHittable)
        export.tap()
        XCTAssertTrue(app.buttons["shopping.export.add"].waitForExistence(timeout: 5))
        app.buttons["shopping.select.potatoes"].tap()
        screenshot(app, "Shopping — Export")
        app.buttons["shopping.export.add"].tap()
        XCTAssertTrue(app.staticTexts["shopping.detail.title"].waitForExistence(timeout: 5))
        screenshot(app, "Shopping — Detail")
        let items = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "shopping.item.")).allElementsBoundByIndex.filter { $0.identifier != "shopping.item.add" }
        XCTAssertFalse(items.contains { $0.label.contains("Pommes de terre") })
        let first = try XCTUnwrap(items.first)
        let identifier = first.identifier
        first.tap()
        for _ in 0..<5 where !app.buttons[identifier].isHittable { app.swipeUp() }
        screenshot(app, "Shopping — Checklist")
        XCTAssertEqual(app.buttons[identifier].value as? String, "Dans le panier")
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        app.tabBars.buttons["Listes"].tap()
        let list = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "shopping.list.")).firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        screenshot(app, "Shopping — Lists")
        list.tap()
        let checked = app.buttons[identifier]
        for _ in 0..<5 where !checked.isHittable { app.swipeUp() }
        XCTAssertEqual(checked.value as? String, "Dans le panier")
        checked.tap()
        app.buttons["shopping.share"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 8))
        screenshot(app, "Shopping — Share")
    }

    @MainActor
    func testShoppingCompletionPersistsWhenLeavingAfterChecking() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-cooking"]
        app.launch()
        app.tabBars.buttons["Listes"].tap()
        app.buttons["shopping.create"].tap()
        let create = app.alerts["Nouvelle liste"]
        XCTAssertTrue(create.waitForExistence(timeout: 4))
        create.textFields.firstMatch.tap()
        create.textFields.firstMatch.typeText("Marché")
        create.buttons["Créer"].tap()
        app.buttons["shopping.item.add"].tap()
        let add = app.alerts["Ajouter un article"]
        add.textFields.element(boundBy: 0).tap()
        add.textFields.element(boundBy: 0).typeText("Citrons")
        add.textFields.element(boundBy: 1).tap()
        add.textFields.element(boundBy: 1).typeText("2")
        add.buttons["Ajouter"].tap()
        let item = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier != %@", "shopping.item.", "shopping.item.add")).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 4))
        let identifier = item.identifier
        item.tap()
        // Leave while the check is settling: purchase data must already be saved.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let list = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "shopping.list.")).firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        XCTAssertEqual(list.value as? String, "Terminée")
        screenshot(app, "Motion — Complete card")
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        app.tabBars.buttons["Listes"].tap()
        list.tap()
        XCTAssertEqual(app.buttons[identifier].value as? String, "Dans le panier")
        screenshot(app, "Motion — Complete list")
        app.buttons[identifier].tap()
        XCTAssertEqual(app.buttons[identifier].value as? String, "À acheter")
    }

    @MainActor
    func testShoppingAislesRecipePortionsAndReusableTemplate() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-cooking"]
        app.launch()
        app.tabBars.buttons["Listes"].tap()
        app.buttons["shopping.create"].tap()
        let create = app.alerts["Nouvelle liste"]
        XCTAssertTrue(create.waitForExistence(timeout: 4))
        create.textFields.firstMatch.tap()
        create.textFields.firstMatch.typeText("Semaine")
        create.buttons["Créer"].tap()

        app.buttons["shopping.options"].tap()
        app.buttons["shopping.recipe.add"].tap()
        app.buttons["shopping.recipe.burger-and-oven-fries"].tap()
        let stepper = app.steppers["shopping.export.servings"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 5))
        stepper.buttons.element(boundBy: 1).tap()
        stepper.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["4 personnes"].exists)
        screenshot(app, "Features — Export portions")
        app.buttons["shopping.export.add"].tap()
        let burger = app.buttons["shopping.source.burger-and-oven-fries"]
        XCTAssertTrue(burger.waitForExistence(timeout: 5))
        XCTAssertTrue(burger.label.contains("4 pers."))
        XCTAssertTrue(app.staticTexts["shopping.aisle.produce"].exists)
        burger.press(forDuration: 1.2)
        app.buttons["shopping.source.details"].tap()
        XCTAssertTrue(app.staticTexts["Pour 4 personnes"].waitForExistence(timeout: 5))
        screenshot(app, "Features — Recipe snapshot")
        app.buttons["Fermer"].tap()

        app.buttons["shopping.options"].tap()
        app.buttons["shopping.recipe.add"].tap()
        app.buttons["shopping.recipe.tomato-mozzarella-toast"].tap()
        XCTAssertTrue(app.buttons["shopping.export.add"].waitForExistence(timeout: 5))
        app.steppers["shopping.export.servings"].buttons.element(boundBy: 1).tap()
        app.buttons["shopping.export.add"].tap()
        XCTAssertTrue(app.buttons["shopping.source.tomato-mozzarella-toast"].waitForExistence(timeout: 5))
        let tomatoPredicate = NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "shopping.item.", "Tomate")
        let tomato = app.buttons.matching(tomatoPredicate).firstMatch
        XCTAssertTrue(tomato.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(tomatoPredicate).count, 1)
        XCTAssertTrue(tomato.label.contains("5"))
        screenshot(app, "Features — Aisles and recipes")
        tomato.press(forDuration: 1.2)
        app.buttons["Changer de rayon"].tap()
        app.buttons["Épicerie"].tap()
        for _ in 0..<8 where !tomato.isHittable { app.swipeUp() }
        XCTAssertTrue(tomato.isHittable)
        tomato.tap()
        app.buttons["shopping.options"].tap()
        app.buttons["shopping.template.save"].tap()
        let save = app.alerts["Enregistrer un modèle"]
        XCTAssertTrue(save.waitForExistence(timeout: 4))
        save.buttons["Enregistrer"].tap()
        let saved = app.alerts["Modèle enregistré"]
        XCTAssertTrue(saved.waitForExistence(timeout: 4))
        saved.buttons["OK"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["shopping.templates"].tap()
        let templatePredicate = NSPredicate(format: "identifier BEGINSWITH %@", "shopping.template.")
        let template = app.buttons.matching(templatePredicate).firstMatch
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        screenshot(app, "Features — Templates")
        template.tap()
        XCTAssertTrue(app.staticTexts["shopping.detail.title"].waitForExistence(timeout: 5))
        let reused = app.buttons.matching(tomatoPredicate).firstMatch
        for _ in 0..<8 where !reused.isHittable { app.swipeUp() }
        XCTAssertEqual(reused.value as? String, "À acheter")
        screenshot(app, "Features — Reused list")
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        app.tabBars.buttons["Listes"].tap()
        let lists = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "shopping.list."))
        XCTAssertEqual(lists.count, 2)
        app.buttons["shopping.templates"].tap()
        XCTAssertTrue(app.buttons.matching(templatePredicate).firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testShoppingEditingUndoFiltersAndAisleOrder() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-cooking"]
        app.launch()
        app.tabBars.buttons["Listes"].tap()
        app.buttons["shopping.create"].tap()
        let create = app.alerts["Nouvelle liste"]
        XCTAssertTrue(create.waitForExistence(timeout: 4))
        create.textFields.firstMatch.tap()
        create.textFields.firstMatch.typeText("Semaine")
        create.buttons["Créer"].tap()
        for recipeID in ["burger-and-oven-fries", "tomato-mozzarella-toast"] {
            app.buttons["shopping.options"].tap()
            app.buttons["shopping.recipe.add"].tap()
            app.buttons["shopping.recipe.\(recipeID)"].tap()
            XCTAssertTrue(app.buttons["shopping.export.add"].waitForExistence(timeout: 5))
            app.buttons["shopping.export.add"].tap()
            XCTAssertTrue(app.staticTexts["shopping.detail.title"].waitForExistence(timeout: 5))
        }
        let toast = app.buttons["shopping.source.tomato-mozzarella-toast"]
        for _ in 0..<3 where !toast.isHittable { app.scrollViews["shopping.sources"].swipeLeft() }
        toast.tap()
        XCTAssertEqual(toast.value as? String, "Filtre actif")
        XCTAssertTrue(app.staticTexts["shopping.filter.notice"].exists)
        let buns = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "shopping.item.", "Pains à burger"))
        XCTAssertFalse(buns.firstMatch.exists)
        let tomatoPredicate = NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "shopping.item.", "Tomate")
        let tomato = app.buttons.matching(tomatoPredicate).firstMatch
        XCTAssertTrue(tomato.label.contains("3"))
        screenshot(app, "Controls — Recipe filter")
        toast.tap()
        XCTAssertFalse(app.staticTexts["shopping.filter.notice"].exists)

        tomato.press(forDuration: 1.2)
        app.buttons["shopping.item.edit"].tap()
        let name = app.textFields["shopping.edit.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (name.value as? String ?? "").count))
        name.typeText("Tomates cerises")
        let amount = app.textFields["shopping.edit.amount"]
        amount.tap()
        amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (amount.value as? String ?? "").count))
        amount.typeText("500 g")
        app.buttons["shopping.edit.save"].tap()
        screenshot(app, "Controls — Edited article and undo")
        XCTAssertTrue(tomato.waitForExistence(timeout: 4))
        XCTAssertTrue(tomato.label.contains("Tomates cerises"))
        XCTAssertTrue(tomato.label.contains("500 g"))
        // The persistent menu remains available after the temporary capsule expires.
        XCTAssertTrue(app.buttons["shopping.item.add"].waitForExistence(timeout: 7))
        app.buttons["shopping.options"].tap()
        app.buttons["shopping.undo.menu"].tap()
        XCTAssertFalse(tomato.label.contains("cerises"))
        XCTAssertTrue(tomato.label.contains("3"))

        tomato.tap()
        XCTAssertTrue(app.buttons["shopping.undo"].waitForExistence(timeout: 3))
        app.buttons["shopping.undo"].tap()
        XCTAssertEqual(tomato.value as? String, "À acheter")
        tomato.swipeLeft()
        app.buttons["Supprimer"].tap()
        XCTAssertTrue(app.buttons["shopping.undo"].waitForExistence(timeout: 3))
        app.buttons["shopping.undo"].tap()
        XCTAssertTrue(tomato.waitForExistence(timeout: 4))
        XCTAssertEqual(tomato.value as? String, "À acheter")

        app.buttons["shopping.options"].tap()
        app.buttons["shopping.aisles.order"].tap()
        let dairy = app.cells.containing(.staticText, identifier: "shopping.order.dairy").firstMatch
        let produce = app.cells.containing(.staticText, identifier: "shopping.order.produce").firstMatch
        XCTAssertTrue(dairy.waitForExistence(timeout: 5))
        // Grab the native reorder handle and give UIKit time to commit the drop.
        dairy.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).press(forDuration: 1,
            thenDragTo: produce.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.15)),
            withVelocity: .slow, thenHoldForDuration: 1)
        screenshot(app, "Controls — Aisle order")
        app.buttons["shopping.order.save"].tap()
        let aislePredicate = NSPredicate(format: "identifier BEGINSWITH %@", "shopping.aisle.")
        XCTAssertEqual(app.staticTexts.matching(aislePredicate).firstMatch.label, "Produits frais")
        screenshot(app, "Controls — Custom aisle order")
        for _ in 0..<5 where !toast.isHittable { app.swipeDown() }
        toast.tap()
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        app.tabBars.buttons["Listes"].tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "shopping.list.")).firstMatch.tap()
        XCTAssertEqual(app.staticTexts.matching(aislePredicate).firstMatch.label, "Produits frais")
        XCTAssertFalse(app.staticTexts["shopping.filter.notice"].exists)
        XCTAssertEqual(app.buttons["shopping.source.tomato-mozzarella-toast"].value as? String, "Non sélectionnée")
    }

    @MainActor
    func testCustomRecipeAndFlexibleCookingSurviveRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-cooking"]
        app.launch()
        let recipe = app.buttons["home.recipe.burger-and-oven-fries"]
        XCTAssertTrue(recipe.waitForExistence(timeout: 8))
        XCTAssertEqual(app.tabBars.count, 1)
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
        app.buttons["cooking.timer.options"].firstMatch.tap()
        app.buttons["Terminer maintenant"].tap()
        app.buttons["Cuisson vérifiée · terminer"].tap()
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
