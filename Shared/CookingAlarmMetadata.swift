import AlarmKit
import AppIntents
import Foundation

nonisolated struct CookingAlarmMetadata: AlarmMetadata {
    var label: String
    var timerID: String
}

struct OpenCookingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Ouvrir la recette"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "petitchef.openCooking.request")
        NotificationCenter.default.post(name: .init("petitchef.openCooking"), object: nil)
        return .result()
    }
}
