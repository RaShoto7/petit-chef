import Foundation
import UserNotifications

@MainActor
protocol CookingNotificationScheduling: AnyObject {
    var onCookingRequested: (() -> Void)? { get set }
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func synchronize(timers: [CookingTimer], enabled: Bool, now: Date) async throws
}

/// Owns only the petitchef.timer namespace, preserving every unrelated app notification.
@MainActor
final class CookingNotifications: NSObject, CookingNotificationScheduling, UNUserNotificationCenterDelegate {
    var onCookingRequested: (() -> Void)?
    private let center: UNUserNotificationCenter
    private let prefix = "petitchef.timer."

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.identifier.hasPrefix("petitchef.timer.") else { return }
        await MainActor.run {
            self.onCookingRequested?()
            NotificationCenter.default.post(name: Notification.Name("petitchef.openCooking"), object: nil)
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func synchronize(timers: [CookingTimer], enabled: Bool, now: Date) async throws {
        let requests = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()
        let existingIDs = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
        let desiredIDs = Set(enabled ? timers.map(\.id) : [])
        let obsolete = existingIDs.filter { !desiredIDs.contains($0) }
        if !obsolete.isEmpty { center.removePendingNotificationRequests(withIdentifiers: obsolete) }
        let restartedIDs = Set(timers.filter { !$0.isExpired(at: now) }.map(\.id))
        let dismissed = delivered.map { $0.request.identifier }.filter {
            $0.hasPrefix(prefix) && (!desiredIDs.contains($0) || restartedIDs.contains($0))
        }
        if !dismissed.isEmpty { center.removeDeliveredNotifications(withIdentifiers: dismissed) }

        guard enabled else { return }
        for timer in timers where !timer.isExpired(at: now) {
            // Fetching notification settings can suspend; preserve the original deadline exactly.
            let remaining = timer.remaining(at: .now)
            guard remaining > 0 else { continue }
            let content = UNMutableNotificationContent()
            content.title = timer.label
            content.body = "C’est le moment de vérifier la cuisson. Ton petit chef t’attend."
            content.sound = .default
            content.threadIdentifier = "petitchef.cooking"
            content.userInfo = ["stepID": timer.stepID, "timerID": timer.id]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, remaining), repeats: false)
            // Adding the same identifier replaces an extension without duplicating an alert.
            try await center.add(UNNotificationRequest(identifier: timer.id, content: content, trigger: trigger))
        }
    }
}
