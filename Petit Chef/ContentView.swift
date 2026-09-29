import SwiftUI

struct ContentView: View {
    @State private var showCooking = false
    @State private var showSettings = false
    @Environment(CookingStore.self) private var cooking

    var body: some View {
        HomeView(showCooking: $showCooking, openSettings: { showSettings = true })
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
