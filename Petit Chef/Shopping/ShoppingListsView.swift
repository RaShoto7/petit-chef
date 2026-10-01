import SwiftUI

enum ShoppingStyle {
    static let ink = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let muted = Color(red: 0.48, green: 0.48, blue: 0.48)
    static let separator = Color.black.opacity(0.06)
    static let canvas = Color(red: 0.97, green: 0.97, blue: 0.975)
}

struct ShoppingListsView: View {
    @Environment(ShoppingStore.self) private var shopping
    @Binding var path: [UUID]
    var openRecipes: () -> Void
    @State private var showingTemplates = false
    @State private var creating = false
    @State private var title = ""

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Listes")
                        .font(.system(.largeTitle, design: .default, weight: .bold))
                        .tracking(-0.8)
                        .padding(.top, 16)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("shopping.home.title")

                    if shopping.lists.isEmpty {
                        VStack(spacing: 18) {
                            Image(systemName: "checklist")
                                .font(.system(size: 30, weight: .regular))
                                .foregroundStyle(ShoppingStyle.muted)
                            Text("Aucune liste")
                                .font(.system(.title3, design: .default, weight: .medium))
                            Button("Choisir une recette", action: openRecipes)
                                .font(.system(.subheadline, design: .default))
                                .buttonStyle(.glass).controlSize(.large)
                        }
                        .padding(.vertical, 64)
                        .frame(maxWidth: .infinity)
                        .background(.white, in: .rect(cornerRadius: 28))
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(shopping.lists.enumerated()), id: \.element.id) { index, list in
                                NavigationLink(value: list.id) {
                                    HStack(spacing: 20) {
                                        Text(list.title)
                                            .font(.system(.title3, design: .default, weight: .medium))
                                            .tracking(-0.3)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(ShoppingStyle.muted.opacity(0.65))
                                            .accessibilityHidden(true)
                                    }
                                    .padding(.horizontal, 26)
                                    .padding(.vertical, 28)
                                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                                    .background(.white, in: .rect(cornerRadius: 30))
                                    .shadow(color: .black.opacity(0.025), radius: 12, x: 0, y: 4)
                                    .contentShape(.rect(cornerRadius: 30))
                                }
                                .buttonStyle(ShoppingBubbleButtonStyle())
                                .modifier(ShoppingEntrance(delay: min(Double(index) * 0.025, 0.1)))
                                .accessibilityIdentifier("shopping.list.\(list.id)")
                                .accessibilityValue(!list.items.isEmpty && list.remainingCount == 0 ? "Terminée" : "")
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(ShoppingStyle.canvas)
            .fontDesign(.default)
            .foregroundStyle(ShoppingStyle.ink)
            .tint(ShoppingStyle.ink)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingTemplates) {
                ShoppingTemplatesView { id in showingTemplates = false; path.append(id) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Modèles", systemImage: "bookmark") { showingTemplates = true }
                        .accessibilityIdentifier("shopping.templates")
                }
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
        }
    }
}

private struct ShoppingBubbleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// A short fade and four-point arrival, disabled with Reduce Motion.
private struct ShoppingEntrance: ViewModifier {
    var delay: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 4)
            .task {
                guard !appeared else { return }
                if reduceMotion { appeared = true; return }
                do { try await Task.sleep(for: .milliseconds(30)) } catch { return }
                withAnimation(.easeOut(duration: 0.25).delay(delay)) { appeared = true }
            }
    }
}

private struct ShoppingCheckmark: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.2, y: rect.height * 0.52))
            path.addLine(to: CGPoint(x: rect.width * 0.43, y: rect.height * 0.73))
            path.addLine(to: CGPoint(x: rect.width * 0.82, y: rect.height * 0.28))
        }
    }
}

private struct ShoppingCheckControl: View {
    let checked: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().strokeBorder(ShoppingStyle.muted.opacity(0.55), lineWidth: 1)
            Circle().fill(ShoppingStyle.ink).opacity(checked ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: checked)
            ShoppingCheckmark()
                .trim(from: 0, to: checked ? 1 : 0)
                .stroke(.white, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .padding(5)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: checked)
        }
        .frame(width: 23, height: 23)
        .accessibilityHidden(true)
    }
}

struct ShoppingListDetailView: View {
    let listID: UUID
    @Environment(ShoppingStore.self) private var shopping
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var checks = 0
    @State private var pendingMoves: [UUID: Bool] = [:]
    @State private var addingRecipe = false
    @State private var savingTemplate = false
    @State private var savedTemplate = false
    @State private var reference: ShoppingRecipeReference?
    @State private var templateName = ""
    @State private var adding = false
    @State private var renaming = false
    @State private var deleting = false
    @State private var title = ""
    @State private var name = ""
    @State private var amount = ""

    var body: some View {
        Group {
            if let list = shopping.list(listID) {
                let multipleSources = Set(list.items.compactMap(\.sourceLabel)).count > 1 || list.recipes.count > 1
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(list.title)
                                .font(.system(.largeTitle, design: .default, weight: .semibold))
                                .tracking(-0.7)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("shopping.detail.title")
                                .accessibilityAddTraits(.isHeader)
                            if !list.recipes.isEmpty {
                                ScrollView(.horizontal) {
                                    HStack(spacing: 8) {
                                        ForEach(list.recipes) { recipe in
                                            Button { reference = recipe } label: {
                                                Text(recipe.displayLabel)
                                                    .font(.subheadline)
                                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                                    .background(.white, in: .capsule)
                                            }
                                            .buttonStyle(ShoppingBubbleButtonStyle())
                                            .accessibilityLabel(recipe.label)
                                            .accessibilityIdentifier("shopping.source.\(recipe.recipeID)")
                                        }
                                    }
                                }
                                .scrollIndicators(.hidden)
                            }
                        }
                        .padding(.top, 8).padding(.bottom, 4)
                        .modifier(ShoppingEntrance())
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    ForEach(ShoppingAisle.allCases) { aisle in
                        let items = list.items.filter { !isInBasket($0) && $0.aisle == aisle }
                        if !items.isEmpty {
                            Section {
                                ForEach(items) { item in row(item, showSource: multipleSources) }
                            } header: {
                                Text(aisle.title)
                                    .font(.subheadline.weight(.medium))
                                    .textCase(nil)
                                    .foregroundStyle(ShoppingStyle.muted)
                                    .accessibilityIdentifier("shopping.aisle.\(aisle.rawValue)")
                            }
                        }
                    }
                    if list.items.contains(where: { isInBasket($0) }) {
                        Section {
                            ForEach(list.items.filter { isInBasket($0) }) { item in
                                row(item, showSource: multipleSources)
                            }
                        } header: {
                            Text("Dans le panier")
                                .font(.system(.subheadline, design: .default, weight: .medium))
                                .textCase(nil)
                                .foregroundStyle(ShoppingStyle.muted)
                                .padding(.top, 4).padding(.bottom, 6)
                        }
                    }
                    if list.items.isEmpty {
                        Section {
                            Text("Ajoute un article pour commencer.")
                                .font(.system(.body, design: .default))
                                .foregroundStyle(ShoppingStyle.muted)
                                .padding(.vertical, 18)
                        }
                        .listRowBackground(Color.white)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.insetGrouped)
                .listSectionSpacing(20)
                .listRowSeparatorTint(ShoppingStyle.separator)
                .scrollContentBackground(.hidden)
                .background(ShoppingStyle.canvas)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Button { name = ""; amount = ""; adding = true } label: {
                        Label("Ajouter un article", systemImage: "plus")
                            .font(.system(.body, design: .default, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .buttonBorderShape(.capsule)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity)
                    .background(ShoppingStyle.canvas)
                    .accessibilityIdentifier("shopping.item.add")
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: list.shareText) { Label("Partager la liste", systemImage: "square.and.arrow.up") }
                            .accessibilityIdentifier("shopping.share")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Ajouter une recette", systemImage: "book.closed") { addingRecipe = true }
                                .accessibilityIdentifier("shopping.recipe.add")
                            Button("Dupliquer", systemImage: "plus.square.on.square") {
                                if let id = shopping.duplicate(listID) { shopping.requestedListID = id }
                            }
                            .accessibilityIdentifier("shopping.duplicate")
                            Button("Enregistrer comme modèle", systemImage: "bookmark") {
                                templateName = list.title; savingTemplate = true
                            }
                            .disabled(list.items.isEmpty)
                            .accessibilityIdentifier("shopping.template.save")
                            Button("Renommer", systemImage: "pencil") { title = list.title; renaming = true }
                            Button("Supprimer la liste", systemImage: "trash", role: .destructive) { deleting = true }
                        } label: { Label("Options de la liste", systemImage: "ellipsis") }
                        .accessibilityIdentifier("shopping.options")
                    }
                }
            } else { ContentUnavailableView("Liste introuvable", systemImage: "checklist") }
        }
        .onDisappear { pendingMoves.removeAll() }
        .fontDesign(.default)
        .foregroundStyle(ShoppingStyle.ink)
        .tint(ShoppingStyle.ink)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: checks) { _, _ in hapticsEnabled }
        .sheet(isPresented: $addingRecipe) {
            ShoppingRecipePicker(listID: listID) { addingRecipe = false }
        }
        .sheet(item: $reference) { recipe in
            if let list = shopping.list(listID) { ShoppingRecipeSnapshot(list: list, recipe: recipe) }
        }
        .alert("Enregistrer un modèle", isPresented: $savingTemplate) {
            TextField("Nom du modèle", text: $templateName)
            Button("Enregistrer") { shopping.saveTemplate(from: listID, title: templateName); savedTemplate = true }
            Button("Annuler", role: .cancel) {}
        } message: { Text("Tu pourras réutiliser ces articles avec toutes les cases décochées.") }
        .alert("Modèle enregistré", isPresented: $savedTemplate) {
            Button("OK", role: .cancel) {}
        } message: { Text("Retrouve-le avec le bouton Modèles sur l’accueil des listes.") }
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

    private func isInBasket(_ item: ShoppingItem) -> Bool {
        pendingMoves[item.id] ?? item.isChecked
    }

    private func toggle(_ item: ShoppingItem) {
        guard pendingMoves[item.id] == nil else { return }
        checks += 1
        if reduceMotion { shopping.toggle(item.id, in: listID); return }
        // Save the purchase immediately; the delay only allows the check to finish drawing.
        pendingMoves[item.id] = item.isChecked
        withAnimation(.easeInOut(duration: 0.2)) { shopping.toggle(item.id, in: listID) }
        Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(220)) } catch { return }
            guard pendingMoves[item.id] != nil else { return }
            withAnimation(.easeInOut(duration: 0.25)) { _ = pendingMoves.removeValue(forKey: item.id) }
        }
    }

    private func row(_ item: ShoppingItem, showSource: Bool) -> some View {
        Button { toggle(item) } label: {
            HStack(spacing: 16) {
                ShoppingCheckControl(checked: item.isChecked)
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.name)
                        .font(.system(.body, design: .default))
                        .strikethrough(item.isChecked, color: ShoppingStyle.muted.opacity(0.5))
                        .foregroundStyle(item.isChecked ? ShoppingStyle.muted : ShoppingStyle.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if showSource || item.contributions == nil, let source = item.sourceSummary {
                        Text(source).font(.system(.caption2, design: .default)).foregroundStyle(ShoppingStyle.muted)
                    }
                }
                Spacer(minLength: 8)
                if !item.amount.isEmpty {
                    Text(item.amount)
                        .font(.system(.subheadline, design: .default).monospacedDigit())
                        .foregroundStyle(ShoppingStyle.muted)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(minHeight: 46)
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(pendingMoves[item.id] != nil)
        .modifier(ShoppingEntrance())
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        .listRowBackground(Color.white)
        .accessibilityValue(item.isChecked ? "Dans le panier" : "À acheter")
        .accessibilityIdentifier("shopping.item.\(item.id)")
        .contextMenu {
            Menu("Changer de rayon", systemImage: "square.grid.2x2") {
                ForEach(ShoppingAisle.allCases) { aisle in
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                            shopping.setAisle(aisle, for: item.id, in: listID)
                        }
                    } label: {
                        if item.aisle == aisle { Label(aisle.title, systemImage: "checkmark") }
                        else { Text(aisle.title) }
                    }
                }
            }
        }
        .swipeActions {
            Button("Supprimer", role: .destructive) { shopping.removeItem(item.id, from: listID) }
        }
    }
}
