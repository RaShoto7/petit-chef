import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @Binding var showCooking: Bool
    @Environment(CookingStore.self) private var cooking
    @Environment(RecipeLibrary.self) private var library
    @State private var confirmReplacement = false
    @State private var editIngredients = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    private var adjusted: Recipe { library.recipe(from: recipe) }
    private var canResume: Bool { cooking.hasActiveSession && cooking.recipe?.id == recipe.id }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                introduction
                ingredients
                details
            }
            .padding(.horizontal, DesignSystem.Layout.pagePadding)
            .padding(.top, 4)
            .padding(.bottom, 16)
            .frame(maxWidth: DesignSystem.Layout.maximumContentWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            ChefPrimaryButton(title: canResume ? "Reprendre" : "C’est parti", symbol: "play.fill") {
                if canResume { showCooking = true }
                else if cooking.hasActiveSession { confirmReplacement = true }
                else { begin() }
            }
            .accessibilityIdentifier("recipe.start")
            .padding(.top, 8)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $editIngredients) {
            IngredientEditor(draft: library.draft(for: recipe)) { draft in
                library.save(draft, for: recipe.id)
            }
        }
        .confirmationDialog("Une recette est en cours", isPresented: $confirmReplacement, titleVisibility: .visible) {
            Button("Reprendre") { showCooking = true }
            Button("Arrêter et commencer celle-ci", role: .destructive) {
                cooking.abandon()
                begin()
            }
        } message: { Text("Les minuteurs de la recette précédente seront annulés.") }
        .chefScreen()
    }

    private func resize(to servings: Int) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82)) {
            library.resize(recipe, to: servings)
        }
    }

    private func begin() {
        cooking.start(recipe: adjusted)
        showCooking = true
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 18) {
            RecipeArtwork(recipeID: recipe.id)
                .frame(height: 220)
                .frame(maxWidth: .infinity)
            Text(recipe.title)
                .font(DesignSystem.Typography.title)
                .fontDesign(.serif)
                .italic()
                .tracking(-0.8)
                .accessibilityIdentifier("recipe.title")
                .accessibilityAddTraits(.isHeader)
            HStack {
                Label("\(recipe.estimatedTotalMinutes) min", systemImage: "clock")
                    .font(.subheadline).foregroundStyle(DesignSystem.Colors.secondaryInk)
                Spacer()
                HStack(spacing: 0) {
                    ChefIconButton(symbol: "minus", label: "Moins de personnes") { resize(to: adjusted.servings - 1) }
                    .disabled(adjusted.servings <= 1)
                    .accessibilityLabel("Moins de personnes")
                    .accessibilityIdentifier("recipe.servings.minus")
                    Text("\(adjusted.servings) pers.")
                        .font(.subheadline.monospacedDigit())
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("recipe.servings.value")
                    ChefIconButton(symbol: "plus", label: "Plus de personnes") { resize(to: adjusted.servings + 1) }
                    .disabled(adjusted.servings >= 12)
                    .accessibilityLabel("Plus de personnes")
                    .accessibilityIdentifier("recipe.servings.plus")
                }
                .sensoryFeedback(.selection, trigger: adjusted.servings) { _, _ in hapticsEnabled }
            }
        }
    }

    private var ingredients: some View {
        ChefCard {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("Ingrédients").font(DesignSystem.Typography.section)
                    Spacer()
                    ChefIconButton(symbol: "pencil", label: "Modifier les ingrédients") { editIngredients = true }
                        .accessibilityIdentifier("recipe.ingredients.edit")
                }
                ForEach(adjusted.ingredientGroups.filter { !$0.ingredients.isEmpty }) { group in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(group.title).font(.caption).foregroundStyle(.secondary)
                        ForEach(group.ingredients) { ingredient in
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                Text(ingredient.name).font(.subheadline)
                                Spacer(minLength: 0)
                                Text(IngredientFormatting.quantity(ingredient))
                                    .font(.subheadline.weight(.medium).monospacedDigit())
                                    .contentTransition(.numericText())
                                    .multilineTextAlignment(.trailing)
                                    .accessibilityIdentifier("ingredient.quantity.\(ingredient.id)")
                            }
                        }
                    }
                }
            }.padding(20)
        }
    }

    private var details: some View {
        VStack(spacing: 18) {
            ChefCard {
                VStack(alignment: .leading, spacing: 20) {
                    RecipeDisclosure(title: "\(recipe.steps.count) étapes", identifier: "steps") {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 18)
                                    Text(step.title).font(.subheadline)
                                }
                            }
                        }.padding(.top, 16)
                    }
                    Divider()
                    RecipeDisclosure(title: "Matériel", identifier: "equipment") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(recipe.equipment, id: \.self) { Text($0).font(.subheadline) }
                        }.padding(.top, 12)
                    }
                }.padding(20)
            }
            ChefCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Allergènes").font(DesignSystem.Typography.label)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(recipe.allergens, id: \.self) { allergen in
                            HStack(spacing: 10) {
                                AllergenIcon(allergen: allergen).frame(width: 24, height: 28)
                                Text(allergen)
                            }
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(DesignSystem.Colors.sand.opacity(0.24), in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    Text("* Selon les pains, pâtes ou sauces. À vérifier sur les produits et après modification des ingrédients.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }

        }
    }
}

/// Keep the content and glass surface mounted while changing only the clipping height.
/// This avoids replacing the material during the disclosure's layout animation.
private struct RecipeDisclosure<Content: View>: View {
    let title: String
    let identifier: String
    @ViewBuilder var content: Content
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.36)) {
                    expanded.toggle()
                }
            } label: {
                HStack {
                    Text(title).font(DesignSystem.Typography.label)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recipe.disclosure.\(identifier)")
            .accessibilityValue(expanded ? "Déplié" : "Replié")
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: expanded ? nil : 0, alignment: .top)
                .clipped()
                .opacity(expanded ? 1 : 0)
                .accessibilityHidden(!expanded)
                .allowsHitTesting(expanded)
        }
    }
}
