import Foundation
import Observation

/// A shopping list keeps a snapshot: later recipe edits never change planned purchases.
nonisolated struct ShoppingItem: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var amount: String
    var source: String?
    var isChecked = false
}

nonisolated struct ShoppingList: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    var items: [ShoppingItem] = []
    var remainingCount: Int { items.filter { !$0.isChecked }.count }
    var shareText: String {
        ([title, ""] + items.map {
            "\($0.isChecked ? "☑" : "☐") \($0.name)\($0.amount.isEmpty ? "" : " · \($0.amount)")\($0.source.map { " (\($0))" } ?? "")"
        }).joined(separator: "\n")
    }
}

@MainActor @Observable
final class ShoppingStore {
    private(set) var lists: [ShoppingList] = []
    var requestedListID: UUID?
    @ObservationIgnored private let defaults: UserDefaults
    private let key = "petitchef.shopping.lists.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([ShoppingList].self, from: data) {
            lists = saved
        }
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
        let source = "\(recipe.title) · \(recipe.servings) pers."
        // Keep recipe contributions separate: units and preparations may differ.
        lists[index].items += recipe.ingredientGroups.flatMap(\.ingredients)
            .filter { ingredientIDs.contains($0.id) }
            .map { ShoppingItem(name: $0.name,
                                amount: $0.quantity == nil ? $0.unit : IngredientFormatting.quantity($0),
                                source: source) }
        persist()
    }

    func addItem(name: String, amount: String, to listID: UUID) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = lists.firstIndex(where: { $0.id == listID }) else { return }
        lists[index].items.append(ShoppingItem(name: name, amount: amount.trimmingCharacters(in: .whitespacesAndNewlines)))
        persist()
    }

    func toggle(_ itemID: UUID, in listID: UUID) {
        guard let index = lists.firstIndex(where: { $0.id == listID }),
              let item = lists[index].items.firstIndex(where: { $0.id == itemID }) else { return }
        lists[index].items[item].isChecked.toggle()
        persist()
    }

    func removeItem(_ itemID: UUID, from listID: UUID) {
        guard let index = lists.firstIndex(where: { $0.id == listID }) else { return }
        lists[index].items.removeAll { $0.id == itemID }
        persist()
    }

    func rename(_ listID: UUID, to title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let index = lists.firstIndex(where: { $0.id == listID }) else { return }
        lists[index].title = title
        persist()
    }

    func delete(_ listID: UUID) {
        lists.removeAll { $0.id == listID }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(lists) { defaults.set(data, forKey: key) }
    }
}
