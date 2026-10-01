import SwiftUI

private enum ShoppingStyle {
    static let ink = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let muted = Color(red: 0.48, green: 0.48, blue: 0.48)
    static let separator = Color.black.opacity(0.07)
}

struct ShoppingListsView: View {
    @Environment(ShoppingStore.self) private var shopping
    @Binding var path: [UUID]
    var openRecipes: () -> Void
    @State private var creating = false
    @State private var title = ""

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Text("Listes")
                        .font(.system(.largeTitle, design: .default, weight: .bold))
                        .tracking(-0.8)
                        .padding(.top, 16).padding(.bottom, 22)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("shopping.home.title")
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
                .listRowSeparator(.hidden)

                if shopping.lists.isEmpty {
                    Section {
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
                        .padding(.vertical, 70)
                        .frame(maxWidth: .infinity)
                    }.listRowSeparator(.hidden)
                } else {
                    Section {
                        ForEach(Array(shopping.lists.enumerated()), id: \.element.id) { index, list in
                            NavigationLink(value: list.id) {
                                Text(list.title)
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .padding(.vertical, 18)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .modifier(ShoppingEntrance(delay: min(Double(index) * 0.025, 0.1)))
                            .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
                            .accessibilityIdentifier("shopping.list.\(list.id)")
                            .accessibilityValue(!list.items.isEmpty && list.remainingCount == 0 ? "Terminée" : "")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listRowBackground(Color.white)
            .listRowSeparatorTint(ShoppingStyle.separator)
            .background(.white)
            .fontDesign(.default)
            .foregroundStyle(ShoppingStyle.ink)
            .tint(ShoppingStyle.ink)
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
        }
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
    @State private var adding = false
    @State private var renaming = false
    @State private var deleting = false
    @State private var title = ""
    @State private var name = ""
    @State private var amount = ""

    var body: some View {
        Group {
            if let list = shopping.list(listID) {
                let multipleSources = Set(list.items.compactMap(\.source)).count > 1
                List {
                    Section {
                        Text(list.title)
                            .font(.system(.largeTitle, design: .default, weight: .semibold))
                            .tracking(-0.7)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 16).padding(.bottom, 26)
                            .modifier(ShoppingEntrance())
                            .accessibilityIdentifier("shopping.detail.title")
                            .accessibilityAddTraits(.isHeader)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
                    .listRowSeparator(.hidden)
                    if list.items.contains(where: { !isInBasket($0) }) {
                        Section {
                            ForEach(list.items.filter { !isInBasket($0) }) { item in
                                row(item, showSource: multipleSources)
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
                                .padding(.top, 20).padding(.bottom, 8)
                        }
                    }
                    if list.items.isEmpty {
                        Section {
                            Text("Ajoute un article pour commencer.")
                                .font(.system(.body, design: .default))
                                .foregroundStyle(ShoppingStyle.muted)
                                .padding(.vertical, 18)
                        }.listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .listRowSeparatorTint(ShoppingStyle.separator)
                .scrollContentBackground(.hidden)
                .background(.white)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Button { name = ""; amount = ""; adding = true } label: {
                        Label("Ajouter un article", systemImage: "plus")
                            .font(.system(.body, design: .default, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 24).padding(.vertical, 8)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .background(.bar)
                    .overlay(alignment: .top) { ShoppingStyle.separator.frame(height: 0.5) }
                    .accessibilityIdentifier("shopping.item.add")
                }
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
        .onDisappear { pendingMoves.removeAll() }
        .fontDesign(.default)
        .foregroundStyle(ShoppingStyle.ink)
        .tint(ShoppingStyle.ink)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: checks) { _, _ in hapticsEnabled }
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
            withAnimation(.easeInOut(duration: 0.25)) { pendingMoves.removeValue(forKey: item.id) }
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
                    if showSource, let source = item.source {
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
        .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
        .listRowBackground(Color.white)
        .accessibilityValue(item.isChecked ? "Dans le panier" : "À acheter")
        .accessibilityIdentifier("shopping.item.\(item.id)")
        .swipeActions {
            Button("Supprimer", role: .destructive) { shopping.removeItem(item.id, from: listID) }
        }
    }
}
