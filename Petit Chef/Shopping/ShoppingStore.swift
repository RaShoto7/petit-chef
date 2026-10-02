import Foundation
import Observation

nonisolated enum ShoppingAisle: String, Codable, CaseIterable, Identifiable, Hashable {
    case produce, bakery, meat, dairy, pantry, frozen, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .produce: "Fruits & légumes"
        case .bakery: "Pain & boulangerie"
        case .meat: "Viande & poisson"
        case .dairy: "Produits frais"
        case .pantry: "Épicerie"
        case .frozen: "Surgelés"
        case .other: "Autres"
        }
    }

    static func completeOrder(_ preferred: [Self]) -> [Self] {
        var result: [Self] = []
        for aisle in preferred + allCases where !result.contains(aisle) { result.append(aisle) }
        return result
    }

    static func suggested(for name: String) -> Self {
        let words = Set(ShoppingItem.normalized(name).split(separator: " ").map(String.init))
        // Whole words avoid accidental substring matches such as lait / laitue.
        if !words.isDisjoint(with: ["surgele", "surgeles", "surgelee", "surgelees"]) { return .frozen }
        if !words.isDisjoint(with: ["huile", "sauce", "spaghetti", "pates", "riz", "sel", "poivre", "farine", "sucre", "conserve", "epices", "chocolat"]) { return .pantry }
        if !words.isDisjoint(with: ["cheddar", "parmesan", "beurre", "mozzarella", "fromage", "lait", "creme", "yaourt", "oeuf", "oeufs", "œuf", "œufs"]) { return .dairy }
        if !words.isDisjoint(with: ["steak", "steaks", "boeuf", "bœuf", "poulet", "porc", "jambon", "saumon", "thon", "poisson"]) { return .meat }
        if !words.isDisjoint(with: ["pain", "pains", "baguette", "brioche"]) { return .bakery }
        if !words.isDisjoint(with: ["pommes", "pomme", "tomate", "tomates", "oignon", "oignons", "salade", "laitue", "citron", "citrons", "ail", "basilic", "carotte", "carottes", "courgette", "courgettes", "banane", "bananes", "avocat", "avocats", "persil"]) { return .produce }
        return .other
    }
}

/// One export batch: ingredients keep the recipe title and portions used at that moment.
nonisolated struct ShoppingRecipeReference: Codable, Equatable, Identifiable {
    var id = UUID()
    var recipeID: String
    var title: String
    var servings: Int
    var displayTitle: String?
    var displayLabel: String { "\(displayTitle ?? title) · \(servings) pers." }
    var label: String { "\(title) · \(servings) pers." }
}

nonisolated struct ShoppingContribution: Codable, Equatable {
    var recipe: ShoppingRecipeReference
    var amount: String
    var ingredientName: String?
}

/// Optional new fields preserve lists saved by the first version.
nonisolated struct ShoppingItem: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var amount: String
    var source: String?
    var isChecked = false
    var quantity: Double?
    var unit: String?
    var contributions: [ShoppingContribution]?
    var aisleOverride: ShoppingAisle?
    var isManuallyEdited: Bool?

    var aisle: ShoppingAisle { aisleOverride ?? ShoppingAisle.suggested(for: name) }
    var sourceLabel: String? {
        guard let contributions, !contributions.isEmpty else { return source }
        var labels: [String] = []
        for contribution in contributions where !labels.contains(contribution.recipe.label) {
            labels.append(contribution.recipe.label)
        }
        return labels.joined(separator: " · ")
    }

    var sourceSummary: String? {
        guard let contributions, !contributions.isEmpty else { return source }
        var titles: [String] = []
        for contribution in contributions {
            let title = contribution.recipe.displayTitle ?? contribution.recipe.title
            if !titles.contains(title) { titles.append(title) }
        }
        return titles.joined(separator: " · ")
    }

    static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "’", with: "'")
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    var mergeName: String {
        let name = Self.normalized(name)
        // Only explicit food aliases; no guessing by removing a final 's'.
        let aliases = ["tomates": "tomate", "citrons": "citron", "oignons": "oignon",
                       "carottes": "carotte", "courgettes": "courgette"]
        return aliases[name] ?? name
    }

    mutating func refreshAmount() {
        guard let quantity, let unit else { return }
        amount = IngredientFormatting.quantity(Ingredient(id: "shopping", name: name, quantity: quantity, unit: unit, detail: nil))
    }
}

nonisolated struct ShoppingList: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    var items: [ShoppingItem] = []
    var remainingCount: Int { items.filter { !$0.isChecked }.count }
    var recipes: [ShoppingRecipeReference] {
        var result: [ShoppingRecipeReference] = []
        for reference in items.flatMap({ $0.contributions ?? [] }).map(\.recipe) where !result.contains(where: { $0.id == reference.id }) {
            result.append(reference)
        }
        return result
    }
    func items(for referenceID: UUID?) -> [ShoppingItem] {
        guard let referenceID else { return items }
        return items.filter { $0.contributions?.contains(where: { $0.recipe.id == referenceID }) == true }
    }

    var shareText: String { shareText(aisleOrder: ShoppingAisle.allCases) }

    func shareText(aisleOrder: [ShoppingAisle]) -> String {
        var lines = [title, ""]
        for aisle in ShoppingAisle.completeOrder(aisleOrder) {
            let entries = items.filter { $0.aisle == aisle }
            guard !entries.isEmpty else { continue }
            if items.contains(where: { $0.aisle != aisle }) { lines.append(aisle.title) }
            for item in entries {
                lines.append("\(item.isChecked ? "☑" : "☐") \(item.name)\(item.amount.isEmpty ? "" : " · \(item.amount)")")
                if let contributions = item.contributions, !contributions.isEmpty {
                    for contribution in contributions {
                        lines.append("  \(item.isManuallyEdited == true ? "Prévu pour " : "")\(contribution.recipe.label)\(contribution.amount.isEmpty ? "" : " : \(contribution.amount)")")
                    }
                } else if let source = item.source { lines[lines.count - 1] += " (\(source))" }
            }
        }
        return lines.joined(separator: "\n")
    }
}

/// One reversible item operation per list, kept only during this app session.
nonisolated struct ShoppingUndo: Identifiable {
    var id = UUID()
    var item: ShoppingItem
    var index: Int
    var message: String
}

@MainActor @Observable
final class ShoppingStore {
    private(set) var lists: [ShoppingList] = []
    private(set) var templates: [ShoppingList] = []
    private(set) var aisleOrder = ShoppingAisle.allCases
    private(set) var undoActions: [UUID: ShoppingUndo] = [:]
    var requestedListID: UUID?
    @ObservationIgnored private let defaults: UserDefaults
    private let key = "petitchef.shopping.lists.v1"
    private let aisleOrderKey = "petitchef.shopping.aisle-order.v1"
    private let templateKey = "petitchef.shopping.templates.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: aisleOrderKey), let saved = try? JSONDecoder().decode([ShoppingAisle].self, from: data) {
            aisleOrder = ShoppingAisle.completeOrder(saved)
        }
        if let data = defaults.data(forKey: key), let saved = try? JSONDecoder().decode([ShoppingList].self, from: data) { lists = saved }
        if let data = defaults.data(forKey: templateKey), let saved = try? JSONDecoder().decode([ShoppingList].self, from: data) { templates = saved }
    }

    func list(_ id: UUID) -> ShoppingList? { lists.first { $0.id == id } }

    @discardableResult
    func create(title: String) -> UUID {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let list = ShoppingList(title: trimmed.isEmpty ? "Mes courses" : trimmed)
        lists.insert(list, at: 0)
        persist()
        return list.id
    }

    func add(recipe: Recipe, ingredientIDs: Set<String>, to listID: UUID) {
        guard let index = lists.firstIndex(where: { $0.id == listID }) else { return }
        let ingredients = recipe.ingredientGroups.flatMap(\.ingredients).filter { ingredientIDs.contains($0.id) }
        guard !ingredients.isEmpty else { return }
        undoActions.removeValue(forKey: listID)
        let reference = ShoppingRecipeReference(recipeID: recipe.id, title: recipe.title, servings: recipe.servings, displayTitle: recipe.shortTitle)
        for ingredient in ingredients {
            let amount = ingredient.quantity == nil ? ingredient.unit : IngredientFormatting.quantity(ingredient)
            let contribution = ShoppingContribution(recipe: reference, amount: amount, ingredientName: ingredient.name)
            let newItem = ShoppingItem(name: ingredient.name, amount: amount, source: reference.label,
                                       quantity: ingredient.quantity, unit: ingredient.unit, contributions: [contribution])
            // Never reuse purchased items, parse free text or convert incompatible units.
            if let existing = lists[index].items.firstIndex(where: {
                !$0.isChecked && $0.isManuallyEdited != true && $0.contributions != nil && $0.mergeName == newItem.mergeName &&
                $0.unit.map(ShoppingItem.normalized) == ShoppingItem.normalized(ingredient.unit) &&
                ($0.quantity == nil) == (ingredient.quantity == nil)
            }) {
                if let quantity = ingredient.quantity { lists[index].items[existing].quantity = (lists[index].items[existing].quantity ?? 0) + quantity }
                lists[index].items[existing].contributions?.append(contribution)
                lists[index].items[existing].refreshAmount()
            } else { lists[index].items.append(newItem) }
        }
        persist()
    }

    func addItem(name: String, amount: String, to listID: UUID) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = lists.firstIndex(where: { $0.id == listID }) else { return }
        undoActions.removeValue(forKey: listID)
        lists[index].items.append(ShoppingItem(name: name, amount: amount.trimmingCharacters(in: .whitespacesAndNewlines)))
        persist()
    }

    func setAisle(_ aisle: ShoppingAisle, for itemID: UUID, in listID: UUID) {
        guard let index = lists.firstIndex(where: { $0.id == listID }),
              let item = lists[index].items.firstIndex(where: { $0.id == itemID }) else { return }
        guard lists[index].items[item].aisle != aisle else { return }
        remember(lists[index].items[item], at: item, in: listID, message: "Rayon modifié")
        lists[index].items[item].aisleOverride = aisle
        persist()
    }

    func toggle(_ itemID: UUID, in listID: UUID) {
        guard let index = lists.firstIndex(where: { $0.id == listID }),
              let item = lists[index].items.firstIndex(where: { $0.id == itemID }) else { return }
        remember(lists[index].items[item], at: item, in: listID,
                 message: lists[index].items[item].isChecked ? "Retiré du panier" : "Ajouté au panier")
        lists[index].items[item].isChecked.toggle()
        persist()
    }

    func removeItem(_ itemID: UUID, from listID: UUID) {
        guard let index = lists.firstIndex(where: { $0.id == listID }) else { return }
        guard let item = lists[index].items.firstIndex(where: { $0.id == itemID }) else { return }
        remember(lists[index].items[item], at: item, in: listID, message: "Article supprimé")
        lists[index].items.remove(at: item)
        persist()
    }

    func editItem(_ itemID: UUID, in listID: UUID, name: String, amount: String, aisle: ShoppingAisle) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = lists.firstIndex(where: { $0.id == listID }),
              let position = lists[index].items.firstIndex(where: { $0.id == itemID }) else { return }
        let old = lists[index].items[position]
        guard old.name != name || old.amount != amount || old.aisle != aisle else { return }
        remember(old, at: position, in: listID, message: "Article modifié")
        var edited = old
        if old.name != name || old.amount != amount {
            if var contributions = edited.contributions {
                for entry in contributions.indices where contributions[entry].ingredientName == nil {
                    contributions[entry].ingredientName = old.name
                }
                edited.contributions = contributions
            }
            edited.quantity = nil
            edited.unit = nil
            edited.isManuallyEdited = true
        }
        edited.name = name
        edited.amount = amount
        edited.aisleOverride = aisle
        lists[index].items[position] = edited
        persist()
    }

    func setAisleOrder(_ order: [ShoppingAisle]) {
        aisleOrder = ShoppingAisle.completeOrder(order)
        if let data = try? JSONEncoder().encode(aisleOrder) { defaults.set(data, forKey: aisleOrderKey) }
    }

    private func remember(_ item: ShoppingItem, at index: Int, in listID: UUID, message: String) {
        undoActions[listID] = ShoppingUndo(item: item, index: index, message: message)
    }

    func undoLastChange(in listID: UUID) {
        guard let action = undoActions.removeValue(forKey: listID),
              let index = lists.firstIndex(where: { $0.id == listID }) else { return }
        if let position = lists[index].items.firstIndex(where: { $0.id == action.item.id }) {
            lists[index].items[position] = action.item
        } else {
            lists[index].items.insert(action.item, at: min(action.index, lists[index].items.count))
        }
        persist()
    }

    func rename(_ listID: UUID, to title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let index = lists.firstIndex(where: { $0.id == listID }) else { return }
        lists[index].title = title
        persist()
    }

    @discardableResult
    func duplicate(_ listID: UUID) -> UUID? {
        guard let list = list(listID) else { return nil }
        let copy = freshCopy(list)
        lists.insert(copy, at: 0)
        persist()
        return copy.id
    }

    func saveTemplate(from listID: UUID, title: String) {
        guard let list = list(listID), !list.items.isEmpty else { return }
        var copy = freshCopy(list)
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.title = name.isEmpty ? list.title : name
        templates.insert(copy, at: 0)
        persist()
    }

    @discardableResult
    func useTemplate(_ templateID: UUID) -> UUID? {
        guard let template = templates.first(where: { $0.id == templateID }) else { return nil }
        let copy = freshCopy(template)
        lists.insert(copy, at: 0)
        persist()
        return copy.id
    }

    func deleteTemplate(_ id: UUID) {
        templates.removeAll { $0.id == id }
        persist()
    }

    private func freshCopy(_ original: ShoppingList) -> ShoppingList {
        var copy = original
        copy.id = UUID()
        for index in copy.items.indices { copy.items[index].id = UUID(); copy.items[index].isChecked = false }
        return copy
    }

    func delete(_ listID: UUID) {
        undoActions.removeValue(forKey: listID)
        lists.removeAll { $0.id == listID }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(lists) { defaults.set(data, forKey: key) }
        if let data = try? JSONEncoder().encode(templates) { defaults.set(data, forKey: templateKey) }
    }
}
