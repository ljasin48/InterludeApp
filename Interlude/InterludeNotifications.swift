import Foundation
import UserNotifications

enum InterludeNotifications {
    static func requestAccess() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func sync(_ interludes: [SavedInterlude]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let stale = requests.map(\.identifier).filter { $0.hasPrefix("interlude.") && $0.hasSuffix(".start") }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            for interlude in interludes {
                guard let request = startRequest(for: interlude) else { continue }
                center.add(request)
            }
        }
    }

    static func scheduleCompletion(_ interlude: SavedInterlude, at date: Date) {
        let center = UNUserNotificationCenter.current()
        let identifier = completionIdentifier(interlude.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard interlude.notificationPreference != .off, interlude.isRunning else { return }
        let remaining = interlude.remaining(at: date)
        guard remaining >= 1 else { return }
        let content = content(for: interlude)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func cancelCompletion(_ id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [completionIdentifier(id)])
    }

    private static func startRequest(for interlude: SavedInterlude) -> UNNotificationRequest? {
        guard interlude.notificationPreference != .off,
              interlude.isEnabled,
              interlude.runStyle == .automatic,
              !interlude.didFinishSingle else {
            return nil
        }
        var components = DateComponents()
        components.minute = interlude.startMark.rawValue
        components.second = 0
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: interlude.occurrence == .recurring
        )
        let content = content(for: interlude)
        return UNNotificationRequest(identifier: "interlude.\(interlude.id.uuidString).start", content: content, trigger: trigger)
    }

    private static func content(for interlude: SavedInterlude) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = interlude.name
        if interlude.notificationPreference == .bannerAndSound {
            content.sound = .default
        }
        return content
    }

    private static func completionIdentifier(_ id: UUID) -> String {
        "interlude.\(id.uuidString).done"
    }
}
