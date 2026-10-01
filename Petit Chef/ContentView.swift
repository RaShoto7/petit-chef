import SwiftUI

struct ContentView: View {
    @State private var showCooking = false
    @State private var showSettings = false
    @State private var recipePath: [String] = []
    @State private var finishedCooking = false
    @Environment(CookingStore.self) private var cooking

    var body: some View {
        HomeView(showCooking: $showCooking, path: $recipePath, openSettings: { showSettings = true })
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
                    finishedCooking = true
                    showCooking = false
                }
                .navigationTransition(.crossFade)
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
