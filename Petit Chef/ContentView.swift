import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var shoppingPath: [UUID] = []
    @Environment(ShoppingStore.self) private var shopping
    @State private var showCooking = false
    @State private var showSettings = false
    @State private var recipePath: [String] = []
    @State private var finishedCooking = false
    @Environment(CookingStore.self) private var cooking

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Recettes", systemImage: "book.closed", value: 0) {
                HomeView(showCooking: $showCooking, path: $recipePath, openSettings: { showSettings = true })
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
            .fullScreenCover(isPresented: $showCooking, onDismiss: {
                if finishedCooking {
                    cooking.dismissCompletedSession()
                    finishedCooking = false
                }
            }) {
                CookingView {
                    // Reset the destination underneath the cover before its dismissal.
                    // Keep the completed recipe alive until the dismissal finishes.
                    recipePath.removeAll()
                    selectedTab = 0
                    finishedCooking = true
                    showCooking = false
                }
            }
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
