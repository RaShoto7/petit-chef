import SwiftUI

struct IngredientEditor: View {
    @State var draft: RecipeCustomization
    var onSave: (RecipeCustomization) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var history = IngredientEditHistory()
    @State private var selected: Ingredient?

    private var motion: Animation? { reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86) }

    var body: some View {
        NavigationStack {
            List {
                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ingrédients").font(.system(.largeTitle, design: .rounded, weight: .semibold)).tracking(-1)
                        Text("\(draft.servings) personnes").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    ChefIconButton(symbol: "arrow.uturn.backward", label: "Annuler la modification") {
                        withAnimation(motion) { history.undo(&draft) }
                    }.disabled(!history.canUndo).accessibilityIdentifier("ingredients.undo")
                    ChefIconButton(symbol: "arrow.uturn.forward", label: "Rétablir la modification") {
                        withAnimation(motion) { history.redo(&draft) }
                    }.disabled(!history.canRedo).accessibilityIdentifier("ingredients.redo")
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 18, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                ForEach(draft.groups.filter { !$0.ingredients.isEmpty }) { group in
                    Section(group.title) {
                        ForEach(group.ingredients) { ingredient in
                            Button { selected = ingredient } label: {
                                HStack(spacing: 14) {
                                    Text(ingredient.name).foregroundStyle(DesignSystem.Colors.ink)
                                    Spacer(minLength: 8)
                                    Text(IngredientFormatting.quantity(ingredient)).foregroundStyle(.secondary)
                                        .monospacedDigit().contentTransition(.numericText())
                                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                                }
                                .font(.subheadline).padding(.vertical, 8)
                            }
                            .accessibilityIdentifier("ingredients.row.\(ingredient.id)")
                            .swipeActions {
                                Button("Supprimer", role: .destructive) { remove(ingredient.id) }
                            }
                        }
                    }
                }
                Section {
                    Button {
                        selected = Ingredient(id: "custom-" + UUID().uuidString, name: "", quantity: 1, unit: "", detail: nil)
                    } label: {
                        Label("Ajouter un ingrédient", systemImage: "plus").padding(.vertical, 6)
                    }.accessibilityIdentifier("ingredients.add")
                } footer: {
                    Text("Les quantités sont personnalisables. Les instructions restent celles de la recette.")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", systemImage: "checkmark") { onSave(draft); dismiss() }
                        .labelStyle(.iconOnly).disabled(!draft.isValid)
                        .accessibilityIdentifier("ingredients.save")
                }
            }
            .sheet(item: $selected) { ingredient in
                IngredientFieldEditor(ingredient: ingredient, isNew: !contains(ingredient.id), onSave: commit, onDelete: { remove(ingredient.id) })
            }
            .chefScreen()
        }
    }

    private func contains(_ id: String) -> Bool { draft.groups.contains { $0.ingredients.contains { $0.id == id } } }

    private func commit(_ ingredient: Ingredient) {
        var next = draft
        if let group = next.groups.firstIndex(where: { $0.ingredients.contains { $0.id == ingredient.id } }),
           let index = next.groups[group].ingredients.firstIndex(where: { $0.id == ingredient.id }) {
            next.groups[group].ingredients[index] = ingredient
        } else {
            if !next.groups.contains(where: { $0.id == "custom" }) {
                next.groups.append(IngredientGroup(id: "custom", title: "Ajouts", ingredients: []))
            }
            if let index = next.groups.firstIndex(where: { $0.id == "custom" }) { next.groups[index].ingredients.append(ingredient) }
        }
        apply(next)
    }

    private func remove(_ id: String) {
        var next = draft
        for index in next.groups.indices { next.groups[index].ingredients.removeAll { $0.id == id } }
        apply(next)
    }

    private func apply(_ next: RecipeCustomization) {
        history.record(draft, replacingWith: next)
        withAnimation(motion) { draft = next }
    }
}

private struct IngredientFieldEditor: View {
    @State var ingredient: Ingredient
    let isNew: Bool
    var onSave: (Ingredient) -> Void
    var onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusName: Bool

    private var valid: Bool {
        !ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (ingredient.quantity.map { $0.isFinite && $0 > 0 && $0 <= 100_000 } ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nom") {
                    TextField("Ex. Cornichons", text: $ingredient.name)
                        .focused($focusName).submitLabel(.done)
                        .accessibilityIdentifier("ingredients.name.\(ingredient.id)")
                }
                Section("Quantité") {
                    HStack {
                        TextField("Facultative", text: Binding(get: {
                            ingredient.quantity.map { $0.formatted(.number.locale(Locale(identifier: "fr_FR")).precision(.fractionLength(0...2))) } ?? ""
                        }, set: { text in
                            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            ingredient.quantity = trimmed.isEmpty ? nil : Double(trimmed.replacingOccurrences(of: ",", with: ".")) ?? 0
                        }))
                        .keyboardType(.decimalPad).font(.title2.monospacedDigit())
                        .accessibilityIdentifier("ingredients.amount")
                        TextField("Unité", text: $ingredient.unit)
                            .multilineTextAlignment(.trailing).textInputAutocapitalization(.never)
                            .frame(maxWidth: 130).accessibilityIdentifier("ingredients.unit")
                    }.padding(.vertical, 6)
                    HStack(spacing: 10) {
                        ForEach(["g", "ml", "c. à s.", "pièce"], id: \.self) { unit in
                            Button(unit) { ingredient.unit = unit }.buttonStyle(.bordered)
                                .tint(ingredient.unit == unit ? DesignSystem.Colors.accent : .secondary)
                        }
                    }.listRowSeparator(.hidden)
                }
                if !isNew {
                    Section {
                        Button("Supprimer cet ingrédient", role: .destructive) { onDelete(); dismiss() }
                            .accessibilityIdentifier("ingredients.delete")
                    }
                }
            }
            .navigationTitle(isNew ? "Ajouter" : "Ingrédient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Appliquer", systemImage: "checkmark") {
                        ingredient.name = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        ingredient.unit = ingredient.unit.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(ingredient); dismiss()
                    }.labelStyle(.iconOnly).disabled(!valid).accessibilityIdentifier("ingredients.apply")
                }
            }
            .chefScreen()
            .onAppear { focusName = isNew }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
