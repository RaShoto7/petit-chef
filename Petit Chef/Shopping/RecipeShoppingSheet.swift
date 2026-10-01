import SwiftUI

struct RecipeShoppingSheet: View {
    let recipe: Recipe
    var onExport: (() -> Void)?
    @State private var servings: Int
    @Environment(ShoppingStore.self) private var shopping
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String>
    @State private var destination: UUID?
    @State private var title: String

    init(recipe: Recipe, destination: UUID? = nil, onExport: (() -> Void)? = nil) {
        self.recipe = recipe
        self.onExport = onExport
        _servings = State(initialValue: recipe.servings)
        _destination = State(initialValue: destination)
        _selected = State(initialValue: Set(recipe.ingredientGroups.flatMap(\.ingredients).map(\.id)))
        _title = State(initialValue: recipe.shortTitle)
    }

    private var adjusted: Recipe {
        var draft = RecipeCustomization(recipe: recipe)
        draft.resize(to: servings)
        var result = recipe
        result.servings = draft.servings
        result.ingredientGroups = draft.groups
        return result
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
                    Stepper(value: $servings, in: 1...12) {
                        Text(servings == 1 ? "1 personne" : "\(servings) personnes")
                    }
                    .accessibilityIdentifier("shopping.export.servings")
                } header: { Text("Portions") }
                Section {
                    ForEach(adjusted.ingredientGroups.flatMap(\.ingredients)) { ingredient in
                        Button {
                            if selected.contains(ingredient.id) { selected.remove(ingredient.id) }
                            else { selected.insert(ingredient.id) }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: selected.contains(ingredient.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3).foregroundStyle(ShoppingStyle.ink)
                                Text(ingredient.name).foregroundStyle(ShoppingStyle.ink)
                                Spacer()
                                Text(ingredient.quantity == nil ? ingredient.unit : IngredientFormatting.quantity(ingredient))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }.frame(minHeight: 32)
                        }
                        .accessibilityValue(selected.contains(ingredient.id) ? "Sélectionné" : "Non sélectionné")
                        .accessibilityIdentifier("shopping.select.\(ingredient.id)")
                    }
                } header: {
                    Text("Ingrédients")
                } footer: {
                    Text("Décoche ce que tu as déjà. Les portions choisies ici s’appliquent uniquement aux courses.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(ShoppingStyle.canvas)
            .navigationTitle("Préparer les courses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    let id = destination ?? shopping.create(title: title)
                    shopping.add(recipe: adjusted, ingredientIDs: selected, to: id)
                    dismiss()
                    shopping.requestedListID = id
                    onExport?()
                } label: {
                    Text(selected.count == 1 ? "Ajouter 1 ingrédient" : "Ajouter \(selected.count) ingrédients")
                        .foregroundStyle(.white)
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(ShoppingStyle.ink)
                .disabled(selected.isEmpty)
                .accessibilityIdentifier("shopping.export.add")
                .padding()
                .frame(maxWidth: .infinity)
                .background(ShoppingStyle.canvas)
            }
        }
        .fontDesign(.default)
        .tint(ShoppingStyle.ink)
    }
}
