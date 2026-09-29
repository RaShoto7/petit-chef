import SwiftUI

@main
struct Petit_ChefApp: App {
    @State private var cooking = Petit_ChefApp.makeCookingStore()
    @State private var account = AccountStore()
    @State private var library = RecipeLibrary(defaults: ProcessInfo.processInfo.arguments.contains("-ui-testing") ? UserDefaults(suiteName: "com.rafael.PetitChef.UITests")! : .standard)
    @State private var shopping = ShoppingStore(defaults: ProcessInfo.processInfo.arguments.contains("-ui-testing") ? UserDefaults(suiteName: "com.rafael.PetitChef.UITests")! : .standard)
    @Environment(\.scenePhase) private var scenePhase

    private static func makeCookingStore() -> CookingStore {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing"),
           let defaults = UserDefaults(suiteName: "com.rafael.PetitChef.UITests") {
            if ProcessInfo.processInfo.arguments.contains("-reset-cooking") {
                defaults.removePersistentDomain(forName: "com.rafael.PetitChef.UITests")
            }
            let systemAlarmTest = ProcessInfo.processInfo.arguments.contains("-system-alarm-testing")
            defaults.set(systemAlarmTest, forKey: "petitchef.cooking.session.v1.notificationsEnabled")
            if systemAlarmTest {
                return CookingStore(defaults: defaults, notifications: CookingAlarms(), automaticallyRequestsPermission: true)
            }
            return CookingStore(defaults: defaults)
        }
        #endif
        return CookingStore()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(cooking)
                .environment(account)
                .environment(library)
                .environment(shopping)
                .preferredColorScheme(.light)
                .tint(DesignSystem.Colors.ink)
                .fontDesign(.rounded)
                .task {
                    await account.refreshCredentialState()
                    await cooking.refreshNotifications()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task {
                            await account.refreshCredentialState()
                            await cooking.refreshNotifications()
                        }
                    }
                }
        }
    }
}
