import AlarmKit
import SwiftUI
import UserNotifications

/// AlarmKit owns delivery, Lock Screen and Dynamic Island. Recipe completion remains explicit.
@MainActor
final class CookingAlarms: CookingNotificationScheduling {
    var onCookingRequested: (() -> Void)?
    private let manager = AlarmManager.shared
    private let defaults = UserDefaults.standard
    private let key = "petitchef.systemAlarms.v1"
    private var records: [String: Record]
    private var openTask: Task<Void, Never>?

    private struct Record: Codable {
        var id: UUID
        var deadline: Date
        var scheduled: Bool
    }

    init() {
        if let data = defaults.data(forKey: key), let decoded = try? JSONDecoder().decode([String: Record].self, from: data) {
            records = decoded
        } else { records = [:] }
        openTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .init("petitchef.openCooking")) {
                guard !Task.isCancelled else { return }
                self?.onCookingRequested?()
            }
        }
    }

    deinit { openTask?.cancel() }

    func authorizationStatus() async -> UNAuthorizationStatus {
        switch manager.authorizationState {
        case .authorized: .authorized
        case .denied: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await manager.requestAuthorization() == .authorized
    }

    func synchronize(timers: [CookingTimer], enabled: Bool, now: Date) async throws {
        // Remove reminders left by the earlier notification-based implementation.
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("petitchef.timer.") })
        let desired = Set(enabled ? timers.map(\.id) : [])
        guard !records.isEmpty || (enabled && !timers.isEmpty) else { return }
        let existing = Set(try manager.alarms.map(\.id))
        for (timerID, record) in records where !desired.contains(timerID) {
            if existing.contains(record.id) { try manager.cancel(id: record.id) }
            records.removeValue(forKey: timerID)
            save()
        }
        guard enabled else { return }
        for timer in timers where !timer.isExpired(at: now) {
            // An alarm stopped in system UI stays stopped until its duration is explicitly edited.
            if let record = records[timer.id], record.deadline == timer.deadline, record.scheduled { continue }
            let id = records[timer.id]?.id ?? UUID()
            if existing.contains(id) { try manager.cancel(id: id) }
            records[timer.id] = Record(id: id, deadline: timer.deadline, scheduled: false)
            save()
            let presentation = AlarmPresentation(
                alert: .init(title: LocalizedStringResource(stringLiteral: timer.label),
                             secondaryButton: AlarmButton(text: "Recette", textColor: .white, systemImageName: "fork.knife"),
                             secondaryButtonBehavior: .custom),
                countdown: .init(title: LocalizedStringResource(stringLiteral: timer.label))
            )
            let attributes = AlarmAttributes(presentation: presentation,
                                             metadata: CookingAlarmMetadata(label: timer.label, timerID: timer.id),
                                             tintColor: Color(red: 0.33, green: 0.43, blue: 0.32))
            let configuration = AlarmManager.AlarmConfiguration.timer(
                duration: max(1, timer.deadline.timeIntervalSinceNow), attributes: attributes,
                secondaryIntent: OpenCookingIntent())
            _ = try await manager.schedule(id: id, configuration: configuration)
            records[timer.id]?.scheduled = true
            save()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) { defaults.set(data, forKey: key) }
    }
}
