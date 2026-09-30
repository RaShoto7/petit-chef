import SwiftUI

/// A quiet, shared visual language for the shopping screens only.
private enum ShoppingStyle {
    static let background = Color(red: 0.975, green: 0.975, blue: 0.962)
    static let ink = Color(red: 0.15, green: 0.18, blue: 0.16)
    static let muted = Color(red: 0.42, green: 0.46, blue: 0.43)
    static let line = ink.opacity(0.08)

    static func caption(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium, design: .default))
            .tracking(1.8)
            .foregroundStyle(muted)
    }
}

struct ShoppingListsView: View {
    @Environment(ShoppingStore.self) private var shopping
    @Binding var path: [UUID]
    var openRecipes: () -> Void
    @State private var creating = false
    @State private var title = ""
    @ScaledMetric(relativeTo: .largeTitle) private var headingSize = 44

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    VStack(alignment: .leading, spacing: 12) {
                        ShoppingStyle.caption("Petit Chef")
                        HStack(alignment: .firstTextBaseline) {
                            Text("Listes")
                                .font(.system(size: headingSize, weight: .regular, design: .default))
                                .tracking(-1.8)
                                .accessibilityAddTraits(.isHeader)
                            Spacer()
                            if !shopping.lists.isEmpty {
                                Text(shopping.lists.count, format: .number)
                                    .font(.system(.title3, design: .default, weight: .light).monospacedDigit())
                                    .foregroundStyle(ShoppingStyle.muted)
                                    .accessibilityLabel("\(shopping.lists.count) listes")
                            }
                        }
                    }
                    if shopping.lists.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 22) {
                            ForEach(shopping.lists) { list in
                                NavigationLink(value: list.id) {
                                    ShoppingListCard(list: list)
                                }
                                .buttonStyle(TactileButtonStyle())
                                .accessibilityIdentifier("shopping.list.\(list.id)")
                            }
                        }
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, 18)
                .padding(.bottom, 36)
                .frame(maxWidth: DesignSystem.Layout.maximumContentWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
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
            .fontDesign(.default)
            .foregroundStyle(ShoppingStyle.ink)
            .background(ShoppingStyle.background)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 28) {
            ShoppingPaperMark()
                .frame(width: 120, height: 150)
                .padding(.bottom, 8)
            VStack(spacing: 12) {
                Text("Une recette. Et c’est listé.")
                    .font(.system(.title3, design: .default, weight: .medium))
                    .tracking(-0.4)
                Text("Choisis une recette.\nOn s’occupe des ingrédients.")
                    .font(.system(.subheadline, design: .default))
                    .foregroundStyle(ShoppingStyle.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            Button("Choisir une recette", action: openRecipes)
                .buttonStyle(.glass).controlSize(.large)
        }
        .padding(.vertical, 64)
        .frame(maxWidth: .infinity)
    }
}

private struct ShoppingListCard: View {
    let list: ShoppingList
    private var checked: Int { list.items.count - list.remainingCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(list.title)
                        .font(.system(.title2, design: .default, weight: .medium))
                        .tracking(-0.6)
                        .multilineTextAlignment(.leading)
                    Text(list.items.isEmpty ? "Nouvelle liste" : "\(list.items.count) ingrédients")
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(ShoppingStyle.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(ShoppingStyle.muted)
                    .frame(width: 30, height: 30)
                    .background(ShoppingStyle.background, in: .circle)
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(list.remainingCount == 0 && !list.items.isEmpty ? "Prête." : "\(list.remainingCount)")
                        .font(.system(size: 42, weight: .light, design: .default).monospacedDigit())
                        .tracking(-1.5)
                    Text(list.remainingCount == 0 && !list.items.isEmpty ? "Tout est dans le panier" : "à acheter")
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(ShoppingStyle.muted)
                }
                Spacer()
                ShoppingProgressRing(checked: checked, total: list.items.count)
                    .frame(width: 52, height: 52)
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 28))
        .overlay { RoundedRectangle(cornerRadius: 28).strokeBorder(ShoppingStyle.line, lineWidth: 0.7) }
        .background {
            RoundedRectangle(cornerRadius: 28)
                .fill(.white.opacity(0.75))
                .overlay { RoundedRectangle(cornerRadius: 28).strokeBorder(ShoppingStyle.line, lineWidth: 0.6) }
                .padding(.horizontal, 7)
                .offset(y: 7)
        }
        .shadow(color: ShoppingStyle.ink.opacity(0.035), radius: 20, x: 0, y: 12)
        .padding(.bottom, 7)
        .accessibilityElement(children: .combine)
    }
}

private struct ShoppingProgressRing: View {
    let checked: Int
    let total: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(ShoppingStyle.ink.opacity(0.07), lineWidth: 2)
            Circle()
                .trim(from: 0, to: total > 0 ? CGFloat(checked) / CGFloat(total) : 0)
                .stroke(DesignSystem.Colors.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if total > 0 && checked == total {
                Image(systemName: "checkmark").font(.system(size: 16, weight: .medium))
            } else {
                Text("\(checked)/\(total)")
                    .font(.system(size: 11, weight: .medium, design: .default).monospacedDigit())
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: checked)
        .accessibilityLabel("\(checked) sur \(total) dans le panier")
    }
}

/// An abstract paper object, drawn natively so it stays crisp at every text size.
private struct ShoppingPaperMark: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.white)
            .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(ShoppingStyle.line, lineWidth: 0.7) }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(0..<3) { index in
                        HStack(spacing: 12) {
                            Circle().strokeBorder(ShoppingStyle.ink.opacity(0.22), lineWidth: 1).frame(width: 12, height: 12)
                            Capsule().fill(ShoppingStyle.ink.opacity(0.10)).frame(width: index == 1 ? 34 : 46, height: 2)
                        }
                    }
                }.padding(24)
            }
            .rotationEffect(.degrees(-7))
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.75))
                    .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(ShoppingStyle.line, lineWidth: 0.7) }
                    .rotationEffect(.degrees(7))
                    .offset(x: 6, y: 7)
            }
            .shadow(color: ShoppingStyle.ink.opacity(0.06), radius: 18, x: 0, y: 12)
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
    @State private var adding = false
    @State private var renaming = false
    @State private var deleting = false
    @State private var title = ""
    @State private var name = ""
    @State private var amount = ""
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 38
    @ScaledMetric(relativeTo: .largeTitle) private var countSize = 72

    var body: some View {
        Group {
            if let list = shopping.list(listID) {
                let sources = Array(Set(list.items.compactMap(\.source))).sorted()
                List {
                    Section {
                        header(list, sources: sources)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 6, bottom: 24, trailing: 6))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    if list.remainingCount > 0 {
                        Section {
                            ForEach(list.items.filter { !$0.isChecked }) { item in
                                row(item, showSource: sources.count > 1)
                            }
                        } header: { sectionTitle("À acheter", count: list.remainingCount) }
                    }
                    if list.items.contains(where: \.isChecked) {
                        Section {
                            ForEach(list.items.filter(\.isChecked)) { item in
                                row(item, showSource: sources.count > 1)
                            }
                        } header: { sectionTitle("Dans le panier", count: list.items.count - list.remainingCount) }
                    }
                    if list.items.isEmpty {
                        Section {
                            Text("Ajoute les ingrédients d’une recette\nou compose ta liste librement.")
                                .font(.system(.body, design: .default))
                                .foregroundStyle(ShoppingStyle.muted)
                                .lineSpacing(5)
                                .padding(.vertical, 22)
                        }.listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(ShoppingStyle.background)
                .safeAreaInset(edge: .bottom) {
                    Button { name = ""; amount = ""; adding = true } label: {
                        Label("Ajouter un article", systemImage: "plus")
                            .font(.system(.subheadline, design: .default, weight: .medium))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 40)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier("shopping.item.add")
                    .padding(.top, 10).padding(.bottom, 14)
                    .frame(maxWidth: .infinity)
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
        .fontDesign(.default)
        .foregroundStyle(ShoppingStyle.ink)
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

    private func header(_ list: ShoppingList, sources: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ShoppingStyle.caption("Liste de courses")
            Text(list.title)
                .font(.system(size: titleSize, weight: .regular, design: .default))
                .tracking(-1.4)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("shopping.detail.title")
                .accessibilityAddTraits(.isHeader)
            if sources.count == 1, let source = sources.first {
                Text(source)
                    .font(.system(.caption, design: .default))
                    .foregroundStyle(ShoppingStyle.muted)
            }
            HStack(alignment: .center, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(list.remainingCount)")
                        .font(.system(size: countSize, weight: .ultraLight, design: .default).monospacedDigit())
                        .tracking(-3)
                        .contentTransition(.numericText())
                    Text(list.remainingCount == 0 && !list.items.isEmpty ? "tout est prêt" : "à acheter")
                        .font(.system(.subheadline, design: .default))
                        .foregroundStyle(ShoppingStyle.muted)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(list.remainingCount == 0 && !list.items.isEmpty ? "Tout est dans le panier" : "\(list.remainingCount) ingrédients à acheter")
                .accessibilityIdentifier("shopping.progress")
                Spacer(minLength: 0)
                if !list.items.isEmpty {
                    ShoppingProgressRing(checked: list.items.count - list.remainingCount, total: list.items.count)
                        .frame(width: 48, height: 48)
                }
            }.padding(.top, 10)
        }
        .padding(.top, 10)
    }

    private func sectionTitle(_ title: String, count: Int) -> some View {
        HStack {
            ShoppingStyle.caption(title)
            Spacer()
            Text("\(count)")
                .font(.system(size: 11, weight: .medium, design: .default).monospacedDigit())
                .foregroundStyle(ShoppingStyle.muted)
        }.padding(.bottom, 8)
    }

    private func row(_ item: ShoppingItem, showSource: Bool) -> some View {
        Button {
            checks += 1
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) {
                shopping.toggle(item.id, in: listID)
            }
        } label: {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(item.isChecked ? ShoppingStyle.ink : Color.clear)
                    Circle().strokeBorder(item.isChecked ? ShoppingStyle.ink : ShoppingStyle.ink.opacity(0.23), lineWidth: 1)
                    if item.isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }.frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.system(.body, design: .default))
                        .strikethrough(item.isChecked, color: ShoppingStyle.muted.opacity(0.5))
                        .foregroundStyle(item.isChecked ? ShoppingStyle.muted : ShoppingStyle.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if showSource, let source = item.source {
                        Text(source).font(.system(.caption2, design: .default)).foregroundStyle(ShoppingStyle.muted)
                    }
                }
                Spacer(minLength: 0)
                if !item.amount.isEmpty {
                    Text(item.amount)
                        .font(.system(.subheadline, design: .default).monospacedDigit())
                        .foregroundStyle(ShoppingStyle.muted)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(ShoppingStyle.background, in: RoundedRectangle(cornerRadius: 9))
                }
            }
            .frame(minHeight: 48)
            .padding(.vertical, 5)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 16))
        .listRowSeparatorTint(ShoppingStyle.line)
        .listRowBackground(Color.white)
        .accessibilityValue(item.isChecked ? "Dans le panier" : "À acheter")
        .accessibilityIdentifier("shopping.item.\(item.id)")
        .swipeActions {
            Button("Supprimer", role: .destructive) { shopping.removeItem(item.id, from: listID) }
        }
    }
}
