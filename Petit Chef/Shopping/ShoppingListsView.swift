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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var listTransition
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
                                Text(shopping.lists.count == 1 ? "1 liste" : "\(shopping.lists.count) listes")
                                    .font(.system(.caption, design: .default, weight: .medium).monospacedDigit())
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(.white.opacity(0.8), in: .capsule)
                                    .foregroundStyle(ShoppingStyle.muted)
                                    .accessibilityLabel("\(shopping.lists.count) listes")
                            }
                        }
                    }
                    if shopping.lists.isEmpty {
                        emptyState.modifier(ShoppingEntrance(delay: 0.05))
                    } else {
                        LazyVStack(spacing: 22) {
                            ForEach(Array(shopping.lists.enumerated()), id: \.element.id) { index, list in
                                NavigationLink(value: list.id) {
                                    ShoppingListCard(list: list)
                                        .modifier(ShoppingEntrance(delay: min(Double(index) * 0.06, 0.24)))
                                        .matchedTransitionSource(id: list.id, in: listTransition)
                                }
                                .buttonStyle(ShoppingPressStyle())
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
            .navigationDestination(for: UUID.self) { id in
                if reduceMotion { ShoppingListDetailView(listID: id) }
                else {
                    ShoppingListDetailView(listID: id)
                        .navigationTransition(.zoom(sourceID: id, in: listTransition))
                }
            }
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
    private var complete: Bool { !list.items.isEmpty && list.remainingCount == 0 }
    private var preview: [ShoppingItem] { Array(list.items.filter { !$0.isChecked }.prefix(2)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 7) {
                        Circle().fill(complete ? DesignSystem.Colors.accent : ShoppingStyle.ink.opacity(0.3))
                            .frame(width: 4, height: 4)
                        ShoppingStyle.caption(complete ? "Dans le panier" : "Courses")
                    }
                    Text(list.title)
                        .font(.system(.title2, design: .default, weight: .medium))
                        .tracking(-0.7)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                ShoppingPaperMark()
                    .frame(width: 40, height: 50)
                    .padding(.trailing, 4).padding(.top, 4)
            }
            if !preview.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(preview) { item in
                        HStack(spacing: 10) {
                            Circle().strokeBorder(ShoppingStyle.ink.opacity(0.2), lineWidth: 0.8)
                                .frame(width: 9, height: 9)
                            Text(item.name)
                                .font(.system(.subheadline, design: .default))
                                .foregroundStyle(ShoppingStyle.muted)
                                .lineLimit(1)
                        }
                    }
                }.accessibilityHidden(true)
            }
            Rectangle().fill(ShoppingStyle.line).frame(height: 0.5)
            HStack(alignment: .center, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(complete ? "Prête." : "\(list.remainingCount)")
                        .font(.system(size: 36, weight: .light, design: .default).monospacedDigit())
                        .tracking(-1.2)
                        .contentTransition(.numericText())
                    if !complete {
                        Text("à acheter")
                            .font(.system(.caption, design: .default))
                            .foregroundStyle(ShoppingStyle.muted)
                    }
                }
                Spacer(minLength: 0)
                ShoppingProgressRing(checked: checked, total: list.items.count)
                    .frame(width: 42, height: 42)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ShoppingStyle.muted)
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(colors: [.white, complete ? DesignSystem.Colors.sage.opacity(0.32) : Color.white.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay { RoundedRectangle(cornerRadius: 28).strokeBorder(.white, lineWidth: 1) }
        .overlay { RoundedRectangle(cornerRadius: 28).strokeBorder(ShoppingStyle.line, lineWidth: 0.5) }
        .background {
            RoundedRectangle(cornerRadius: 28)
                .fill(.white.opacity(0.65))
                .overlay { RoundedRectangle(cornerRadius: 28).strokeBorder(ShoppingStyle.line, lineWidth: 0.5) }
                .padding(.horizontal, 8).offset(y: 8)
        }
        .shadow(color: ShoppingStyle.ink.opacity(0.045), radius: 22, x: 0, y: 12)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
    }
}

/// Each appearance finishes in a single, finite spring; no perpetual movement.
private struct ShoppingEntrance: ViewModifier {
    var delay: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 14)
            .blur(radius: appeared || reduceMotion ? 0 : 2)
            .task {
                guard !appeared else { return }
                if reduceMotion { appeared = true; return }
                do { try await Task.sleep(for: .milliseconds(30)) } catch { return }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.88).delay(delay)) {
                    appeared = true
                }
            }
    }
}

private struct ShoppingPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .rotation3DEffect(.degrees(configuration.isPressed && !reduceMotion ? 1 : 0), axis: (x: 1, y: 0, z: 0))
            .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.8), value: configuration.isPressed)
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
            Circle().strokeBorder(ShoppingStyle.ink.opacity(0.23), lineWidth: 1)
            Circle().fill(ShoppingStyle.ink)
                .scaleEffect(checked ? 1 : 0.01).opacity(checked ? 1 : 0)
                .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.7), value: checked)
            ShoppingCheckmark()
                .trim(from: 0, to: checked ? 1 : 0)
                .stroke(.white, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .padding(5)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.22).delay(checked ? 0.08 : 0), value: checked)
        }.frame(width: 24, height: 24).accessibilityHidden(true)
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
            } else if total == 0 {
                Image(systemName: "minus").font(.system(size: 11, weight: .regular))
            } else {
                Text("\(checked)/\(total)")
                    .font(.system(size: 11, weight: .medium, design: .default).monospacedDigit())
                    .contentTransition(.numericText())
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.85), value: checked)
        .accessibilityLabel(total == 0 ? "Liste vide" : "\(checked) sur \(total) dans le panier")
    }
}

/// An abstract paper object, drawn natively so it stays crisp at every text size.
private struct ShoppingPaperMark: View {
    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: geometry.size.width * 0.17)
                .fill(.white)
                .overlay { RoundedRectangle(cornerRadius: geometry.size.width * 0.17).strokeBorder(ShoppingStyle.line, lineWidth: 0.7) }
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: geometry.size.height * 0.12) {
                        ForEach(0..<3) { index in
                            HStack(spacing: geometry.size.width * 0.10) {
                                Circle().strokeBorder(ShoppingStyle.ink.opacity(0.22), lineWidth: 1).frame(width: geometry.size.width * 0.10, height: geometry.size.width * 0.10)
                                Capsule().fill(ShoppingStyle.ink.opacity(0.10)).frame(width: geometry.size.width * (index == 1 ? 0.28 : 0.38), height: 1.5)
                            }
                        }
                    }.padding(geometry.size.width * 0.20)
                }
                .rotationEffect(.degrees(-7))
                .background {
                    RoundedRectangle(cornerRadius: geometry.size.width * 0.17)
                        .fill(.white.opacity(0.75))
                        .overlay { RoundedRectangle(cornerRadius: geometry.size.width * 0.17).strokeBorder(ShoppingStyle.line, lineWidth: 0.7) }
                        .rotationEffect(.degrees(7))
                        .offset(x: 6, y: 7)
                }
                .shadow(color: ShoppingStyle.ink.opacity(0.06), radius: 18, x: 0, y: 12)
                .accessibilityHidden(true)
        }
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
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 38
    @ScaledMetric(relativeTo: .largeTitle) private var countSize = 60

    var body: some View {
        Group {
            if let list = shopping.list(listID) {
                let sources = Array(Set(list.items.compactMap(\.source))).sorted()
                List {
                    Section {
                        header(list, sources: sources)
                            .modifier(ShoppingEntrance(delay: 0.02))
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 6, bottom: 24, trailing: 6))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    if list.items.contains(where: { !isInBasket($0) }) {
                        Section {
                            ForEach(list.items.filter { !isInBasket($0) }) { item in
                                row(item, showSource: sources.count > 1)
                            }
                        } header: { sectionTitle("À acheter", count: list.remainingCount) }
                    }
                    if list.items.contains(where: { isInBasket($0) }) {
                        Section {
                            ForEach(list.items.filter { isInBasket($0) }) { item in
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
        .onDisappear { pendingMoves.removeAll() }
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
                        .tracking(-2)
                        .lineLimit(1).minimumScaleFactor(0.6)
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

    private func isInBasket(_ item: ShoppingItem) -> Bool {
        pendingMoves[item.id] ?? item.isChecked
    }

    private func rowDelay(_ item: ShoppingItem) -> Double {
        let index = shopping.list(listID)?.items.firstIndex(where: { $0.id == item.id }) ?? 0
        return min(Double(index) * 0.035, 0.18)
    }

    private func toggle(_ item: ShoppingItem) {
        guard pendingMoves[item.id] == nil else { return }
        checks += 1
        if reduceMotion {
            shopping.toggle(item.id, in: listID)
            return
        }
        // Persist immediately, but leave the row in place long enough to see the check draw.
        // Dismissing during this visual phase cannot lose a purchase.
        pendingMoves[item.id] = item.isChecked
        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
            shopping.toggle(item.id, in: listID)
        }
        Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(340)) } catch { return }
            guard pendingMoves[item.id] != nil else { return }
            withAnimation(.smooth(duration: 0.45)) { pendingMoves.removeValue(forKey: item.id) }
        }
    }

    private func row(_ item: ShoppingItem, showSource: Bool) -> some View {
        Button { toggle(item) } label: {
            HStack(alignment: .center, spacing: 16) {
                ShoppingCheckControl(checked: item.isChecked)
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
        .disabled(pendingMoves[item.id] != nil)
        .modifier(ShoppingEntrance(delay: rowDelay(item)))
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
