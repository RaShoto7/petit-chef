import SwiftUI

struct HomeView: View {
    @Environment(CookingStore.self) private var cooking
    @Binding var showCooking: Bool
    @Binding var path: [String]
    var openSettings: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var headingSize = 42
    @Namespace private var recipeTransition

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("mes recettes.")
                        .font(.system(size: headingSize, weight: .regular, design: .serif).italic())
                        .fontDesign(.serif)
                        .italic()
                        .tracking(-1.8)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("home.title")
                    if cooking.hasActiveSession { resumeCard }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], alignment: .leading, spacing: 18) {
                        ForEach(RecipeCatalog.recipes) { recipe in
                            NavigationLink(value: recipe.id) {
                                VStack(alignment: .leading, spacing: 10) {
                                    RecipeArtwork(recipeID: recipe.id)
                                        .aspectRatio(1, contentMode: .fit)
                                    Text(recipe.shortTitle)
                                        .font(.system(.headline, design: .rounded, weight: .semibold))
                                        .lineLimit(2)
                                        .frame(height: 44, alignment: .topLeading)
                                    Text("\(recipe.estimatedTotalMinutes) min")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(DesignSystem.Colors.secondaryInk)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 26))
                                .overlay { RoundedRectangle(cornerRadius: 26).stroke(.black.opacity(0.055), lineWidth: 0.7) }
                                .matchedTransitionSource(id: recipe.id, in: recipeTransition)
                            }
                            .buttonStyle(TactileButtonStyle())
                            .accessibilityIdentifier("home.recipe.\(recipe.id)")
                            .accessibilityLabel("\(recipe.shortTitle), \(recipe.estimatedTotalMinutes) minutes")
                        }
                    }
                }
                .padding(DesignSystem.Layout.pagePadding)
                .frame(maxWidth: DesignSystem.Layout.maximumContentWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Profil et réglages", systemImage: "person.crop.circle", action: openSettings)
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("home.account")
                }
            }
            .navigationDestination(for: String.self) { id in
                if let recipe = RecipeCatalog.recipes.first(where: { $0.id == id }) {
                    RecipeDetailView(recipe: recipe, showCooking: $showCooking)
                        .navigationTransition(.zoom(sourceID: recipe.id, in: recipeTransition))
                }
            }
            .chefScreen()
        }
    }

    private var resumeCard: some View {
        Button { showCooking = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "timer")
                VStack(alignment: .leading, spacing: 3) {
                    Text("Reprendre").font(.subheadline.weight(.semibold))
                    Text(cooking.recipe?.shortTitle ?? "Recette en cours").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "play.fill").font(.caption)
            }.padding(12)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.roundedRectangle(radius: 22))
        .accessibilityIdentifier("home.resume")
    }
}
