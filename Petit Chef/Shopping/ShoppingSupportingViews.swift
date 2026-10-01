import SwiftUI

struct ShoppingRecipePicker: View {
    let listID: UUID
    var onExport: () -> Void
    @Environment(RecipeLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Recipe?

    var body: some View {
        Group {
            if let selected {
                RecipeShoppingSheet(recipe: library.recipe(from: selected), destination: listID, onExport: onExport)
            } else {
                NavigationStack {
                    List(RecipeCatalog.recipes) { recipe in
                        Button { selected = recipe } label: {
                            HStack {
                                Text(recipe.title).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 8)
                        }
                        .accessibilityIdentifier("shopping.recipe.\(recipe.id)")
                    }
                    .scrollContentBackground(.hidden)
                    .background(ShoppingStyle.canvas)
                    .navigationTitle("Ajouter une recette")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                    }
                }
            }
        }
        .tint(ShoppingStyle.ink)
        .fontDesign(.default)
    }
}

/// Shows the exported snapshot, rather than today's potentially edited recipe.
struct ShoppingRecipeSnapshot: View {
    let list: ShoppingList
    let recipe: ShoppingRecipeReference
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(recipe.title).font(.title2.weight(.semibold))
                    Text(recipe.servings == 1 ? "Pour 1 personne" : "Pour \(recipe.servings) personnes")
                        .foregroundStyle(.secondary)
                }
                Section {
                    ForEach(list.items.filter { item in item.contributions?.contains(where: { $0.recipe.id == recipe.id }) == true }) { item in
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.name)
                            Spacer()
                            Text((item.contributions ?? []).filter { $0.recipe.id == recipe.id }.map(\.amount).filter { !$0.isEmpty }.joined(separator: " + "))
                                .foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                        }
                        .padding(.vertical, 4)
                    }
                } header: { Text("Dans cette liste") } footer: {
                    Text("Quantités prévues lors de l’ajout. Modifier la recette ensuite ne change pas ces courses.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(ShoppingStyle.canvas)
            .accessibilityIdentifier("shopping.source.snapshot")
            .navigationTitle("Recette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } } }
        }
        .tint(ShoppingStyle.ink)
        .fontDesign(.default)
    }
}

struct ShoppingTemplatesView: View {
    var onUse: (UUID) -> Void
    @Environment(ShoppingStore.self) private var shopping
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if shopping.templates.isEmpty {
                    ContentUnavailableView {
                        Label("Tes listes réutilisables", systemImage: "bookmark")
                    } description: {
                        Text("Dans une liste, ouvre le menu puis choisis « Enregistrer comme modèle ».")
                    }
                } else {
                    List {
                        Section {
                            ForEach(shopping.templates) { template in
                                Button {
                                    if let id = shopping.useTemplate(template.id) { onUse(id) }
                                } label: {
                                    HStack {
                                        Text(template.title).font(.body.weight(.medium)).foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "plus").foregroundStyle(.secondary)
                                    }.padding(.vertical, 14)
                                }
                                .accessibilityIdentifier("shopping.template.\(template.id)")
                                .swipeActions {
                                    Button("Supprimer", role: .destructive) { shopping.deleteTemplate(template.id) }
                                }
                            }
                        } footer: { Text("Un tap crée une nouvelle liste. Le modèle reste disponible et toutes les cases sont décochées.") }
                    }
                    .scrollContentBackground(.hidden)
                    .background(ShoppingStyle.canvas)
                }
            }
            .navigationTitle("Modèles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } } }
        }
        .tint(ShoppingStyle.ink)
        .fontDesign(.default)
    }
}
