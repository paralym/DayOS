import UserNotifications
import Foundation

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    // MARK: - Setup

    func setup() {
        UNUserNotificationCenter.current().delegate = self
        registerCategories()
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error { print("[DAYOS] Notification auth error: \(error)") }
            if granted { print("[DAYOS] Notifications authorized") }
        }
    }

    private func registerCategories() {
        let onTrack   = UNNotificationAction(identifier: "ON_TRACK",        title: "✓  On Track",       options: [])
        let behind    = UNNotificationAction(identifier: "FALLING_BEHIND",   title: "⚠  Falling Behind", options: [])
        let completed = UNNotificationAction(identifier: "MARK_DONE",        title: "★  Mark Complete",  options: [.foreground])

        let category = UNNotificationCategory(
            identifier: "HALFWAY_CHECK",
            actions: [onTrack, behind, completed],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Schedule / Cancel

    func scheduleHalfway(for todo: Todo) {
        let midpoint = todo.midpointTime
        guard midpoint > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "⚡ HALFWAY CHECKPOINT"
        content.body  = "\(todo.priority.symbol) \(todo.title.uppercased())\n\(todo.startTime.timeString) → \(todo.endTime.timeString)  [\(todo.durationString)]\nHow are you doing?"
        content.sound = .default
        content.categoryIdentifier = "HALFWAY_CHECK"
        content.userInfo = ["todoId": todo.id.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: midpoint.timeIntervalSinceNow,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: notificationId(for: todo.id),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("[DAYOS] Failed to schedule: \(error)") }
        }
    }

    func cancelHalfway(for id: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationId(for: id)])
    }

    private func notificationId(for id: UUID) -> String { "halfway_\(id.uuidString)" }

    // MARK: - Delegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let idStr = info["todoId"] as? String,
              let id = UUID(uuidString: idStr) else { return }

        if response.actionIdentifier == "MARK_DONE" {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .todoCompletedFromNotification,
                    object: nil,
                    userInfo: ["todoId": id]
                )
            }
        }
    }
}
