import SwiftUI

struct ShoppingListsView: View {
    @Environment(ShoppingStore.self) private var shopping
    @Binding var path: [UUID]
    var openRecipes: () -> Void
    @State private var creating = false
    @State private var title = ""
    @ScaledMetric(relativeTo: .largeTitle) private var headingSize = 38

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("mes listes.")
                            .font(.system(size: headingSize, weight: .medium)).tracking(-1.5)
                            .accessibilityAddTraits(.isHeader)
                        Text("Tout pour passer à table.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if shopping.lists.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "basket")
                                .font(.system(size: 48, weight: .ultraLight))
                                .frame(width: 104, height: 104)
                                .background(DesignSystem.Colors.sand.opacity(0.3), in: .circle)
                            Text("Une recette. Et c’est listé.")
                                .font(.title3.weight(.medium))
                            Text("Retrouve ici les ingrédients de tes recettes, prêts pour les courses.")
                                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            Button("Choisir une recette", action: openRecipes)
                                .buttonStyle(.glass).controlSize(.large)
                        }
                        .padding(.vertical, 56).frame(maxWidth: .infinity)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(shopping.lists) { list in
                                NavigationLink(value: list.id) {
                                    HStack(spacing: 16) {
                                        Image(systemName: list.remainingCount == 0 && !list.items.isEmpty ? "checkmark" : "checklist")
                                            .font(.title3.weight(.light))
                                            .frame(width: 48, height: 48)
                                            .background(DesignSystem.Colors.sand.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(list.title).font(.headline).multilineTextAlignment(.leading)
                                            Text(list.items.isEmpty ? "À remplir selon tes envies" : list.remainingCount == 0 ? "Tout est dans le panier" : "\(list.remainingCount) à acheter · \(list.items.count) ingrédients")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                    }
                                    .padding(18)
                                    .background(.white, in: RoundedRectangle(cornerRadius: 26))
                                    .overlay { RoundedRectangle(cornerRadius: 26).stroke(.black.opacity(0.06), lineWidth: 1) }
                                }
                                .buttonStyle(TactileButtonStyle())
                                .accessibilityIdentifier("shopping.list.\(list.id)")
                            }
                        }
                    }
                }
                .padding(DesignSystem.Layout.pagePadding)
                .frame(maxWidth: DesignSystem.Layout.maximumContentWidth)
                .frame(maxWidth: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Nouvelle liste", systemImage: "plus") { title = ""; creating = true }
                        .accessibilityIdentifier("shopping.create")
                }
            }
            .navigationDestination(for: UUID.self) { ShoppingListDetailView(listID: $0) }
            .alert("Nouvelle liste", isPresented: $creating) {
                TextField("Mes courses", text: $title)
                Button("Créer") { path.append(shopping.create(title: title)) }
                Button("Annuler", role: .cancel) {}
            }
            .chefScreen()
        }
    }
}

struct ShoppingListDetailView: View {
    let listID: UUID
    @Environment(ShoppingStore.self) private var shopping
    @Environment(\.dismiss) private var dismiss
    @State private var adding = false
    @State private var renaming = false
    @State private var deleting = false
    @State private var title = ""
    @State private var name = ""
    @State private var amount = ""

    var body: some View {
        Group {
            if let list = shopping.list(listID) {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(list.title).font(.largeTitle.weight(.medium)).tracking(-1)
                                .accessibilityIdentifier("shopping.detail.title")
                            Text(list.items.isEmpty ? "Ta prochaine recette commence ici." : list.remainingCount == 0 ? "Tout est dans le panier. À table !" : list.remainingCount == 1 ? "1 ingrédient à acheter" : "\(list.remainingCount) ingrédients à acheter")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .accessibilityIdentifier("shopping.progress")
                            if !list.items.isEmpty {
                                ProgressView(value: Double(list.items.count - list.remainingCount), total: Double(list.items.count))
                                    .tint(DesignSystem.Colors.accent)
                                    .accessibilityLabel("Ingrédients dans le panier")
                            }
                        }.padding(.vertical, 12)
                    }.listRowBackground(Color.clear).listRowSeparator(.hidden)
                    Section {
                        ForEach(list.items.filter { !$0.isChecked }) { item in row(item) }
                        Button { name = ""; amount = ""; adding = true } label: {
                            Label("Ajouter un article", systemImage: "plus").frame(minHeight: 40)
                        }.accessibilityIdentifier("shopping.item.add")
                    } header: { if !list.items.isEmpty { Text("À acheter") } }
                    if list.items.contains(where: \.isChecked) {
                        Section("Dans le panier") {
                            ForEach(list.items.filter(\.isChecked)) { item in row(item) }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(DesignSystem.Colors.sand.opacity(0.12))
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: list.shareText) { Label("Partager la liste", systemImage: "square.and.arrow.up") }
                            .accessibilityIdentifier("shopping.share")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Renommer", systemImage: "pencil") { title = list.title; renaming = true }
                            Button("Supprimer la liste", systemImage: "trash", role: .destructive) { deleting = true }
                        } label: { Label("Options de la liste", systemImage: "ellipsis") }
                    }
                }
            } else { ContentUnavailableView("Liste introuvable", systemImage: "checklist") }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Ajouter un article", isPresented: $adding) {
            TextField("Article", text: $name)
            TextField("Quantité (facultatif)", text: $amount)
            Button("Ajouter") { shopping.addItem(name: name, amount: amount, to: listID) }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Annuler", role: .cancel) {}
        }
        .alert("Renommer la liste", isPresented: $renaming) {
            TextField("Nom", text: $title)
            Button("Enregistrer") { shopping.rename(listID, to: title) }
            Button("Annuler", role: .cancel) {}
        }
        .confirmationDialog("Supprimer cette liste ?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Supprimer la liste", role: .destructive) { shopping.delete(listID); dismiss() }
        } message: { Text("Tous ses articles seront supprimés.") }
    }

    private func row(_ item: ShoppingItem) -> some View {
        Button { shopping.toggle(item.id, in: listID) } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(item.isChecked ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryInk.opacity(0.55))
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.name).strikethrough(item.isChecked).foregroundStyle(item.isChecked ? .secondary : .primary)
                    if let source = item.source { Text(source).font(.caption2).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 4)
                if !item.amount.isEmpty { Text(item.amount).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.trailing) }
            }.padding(.vertical, 8).frame(minHeight: 44)
        }
        .tint(DesignSystem.Colors.ink)
        .accessibilityValue(item.isChecked ? "Dans le panier" : "À acheter")
        .accessibilityIdentifier("shopping.item.\(item.id)")
        .swipeActions {
            Button("Supprimer", role: .destructive) { shopping.removeItem(item.id, from: listID) }
        }
    }
}
