import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var shoppingPath: [UUID] = []
    @Environment(ShoppingStore.self) private var shopping
    @State private var showCooking = false
    @State private var showSettings = false
    @Environment(CookingStore.self) private var cooking

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Recettes", systemImage: "book.closed", value: 0) {
                HomeView(showCooking: $showCooking, openSettings: { showSettings = true })
            }
            Tab("Listes", systemImage: "checklist", value: 1) {
                ShoppingListsView(path: $shoppingPath) { selectedTab = 0 }
            }
        }
            .onChange(of: shopping.requestedListID) { _, id in
                guard let id else { return }
                shoppingPath = [id]
                selectedTab = 1
                shopping.requestedListID = nil
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showCooking) { CookingView() }
            .onChange(of: cooking.presentationRequested, initial: true) { _, requested in
                if requested && cooking.hasActiveSession {
                    showCooking = true
                    cooking.consumePresentationRequest()
                }
            }
            .onOpenURL { url in
                if url.host == "cooking", cooking.hasActiveSession { showCooking = true }
            }
    }
}
