import SwiftUI

struct RecipeShoppingSheet: View {
    let recipe: Recipe
    @Environment(ShoppingStore.self) private var shopping
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String>
    @State private var destination: UUID?
    @State private var title: String

    init(recipe: Recipe) {
        self.recipe = recipe
        _selected = State(initialValue: Set(recipe.ingredientGroups.flatMap(\.ingredients).map(\.id)))
        _title = State(initialValue: recipe.shortTitle)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Ajouter à", selection: $destination) {
                        Text("Nouvelle liste").tag(UUID?.none)
                        ForEach(shopping.lists) { list in Text(list.title).tag(Optional(list.id)) }
                    }
                    if destination == nil {
                        TextField("Nom de la liste", text: $title)
                            .accessibilityIdentifier("shopping.export.name")
                    }
                }
                Section {
                    ForEach(recipe.ingredientGroups.flatMap(\.ingredients)) { ingredient in
                        Button {
                            if selected.contains(ingredient.id) { selected.remove(ingredient.id) }
                            else { selected.insert(ingredient.id) }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: selected.contains(ingredient.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3).foregroundStyle(DesignSystem.Colors.accent)
                                Text(ingredient.name).foregroundStyle(DesignSystem.Colors.ink)
                                Spacer()
                                Text(ingredient.quantity == nil ? ingredient.unit : IngredientFormatting.quantity(ingredient))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }.frame(minHeight: 32)
                        }
                        .accessibilityValue(selected.contains(ingredient.id) ? "Sélectionné" : "Non sélectionné")
                        .accessibilityIdentifier("shopping.select.\(ingredient.id)")
                    }
                } header: {
                    Text(recipe.servings == 1 ? "Pour 1 personne" : "Pour \(recipe.servings) personnes")
                } footer: {
                    Text("Décoche ce que tu as déjà. Les quantités reprennent tes ajustements de la recette.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.sand.opacity(0.18))
            .navigationTitle("Préparer les courses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    let id = destination ?? shopping.create(title: title)
                    shopping.add(recipe: recipe, ingredientIDs: selected, to: id)
                    dismiss()
                    shopping.requestedListID = id
                } label: {
                    Text(selected.count == 1 ? "Ajouter 1 ingrédient" : "Ajouter \(selected.count) ingrédients")
                        .foregroundStyle(.white)
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(DesignSystem.Colors.ink)
                .disabled(selected.isEmpty)
                .accessibilityIdentifier("shopping.export.add")
                .padding()
            }
        }
    }
}
