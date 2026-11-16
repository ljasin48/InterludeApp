import Foundation
import WidgetKit

struct InterludeRecord: Codable, Identifiable {
    var id: UUID
    var name: String
    var symbolName: String
    var tintName: String
    var detail: String
    var type: String
    var repeatMinutes: Int
    var durationMinutes: Int?
    var runStyle: String
    var startMark: Int
    var occurrence: String
    var notificationPreference: String? = nil
    var alertsEnabled: Bool? = nil
    var isEnabled: Bool
    var didFinishSingle: Bool
    var isRunning: Bool? = nil
    var cycleSeconds: TimeInterval? = nil
    var cycleEnd: Date? = nil
    var pausedElapsed: TimeInterval? = nil
}

enum InterludeLibraryStore {
    static let suiteName = "group.com.loganjasin.Interlude"
    static let storageKey = "interludes"

    static func save(_ interludes: [SavedInterlude]) {
        let now = Date()
        let records = interludes.map { interlude in
            InterludeRecord(
                id: interlude.id,
                name: interlude.name,
                symbolName: interlude.symbolName,
                tintName: interlude.tintName,
                detail: interlude.detail,
                type: interlude.type.rawValue,
                repeatMinutes: interlude.repeatMinutes,
                durationMinutes: interlude.durationMinutes,
                runStyle: interlude.runStyle.rawValue,
                startMark: interlude.startMark.rawValue,
                occurrence: interlude.occurrence.rawValue,
                alertsEnabled: interlude.alertsEnabled,
                isEnabled: interlude.isEnabled,
                didFinishSingle: interlude.didFinishSingle,
                isRunning: interlude.isRunning,
                cycleSeconds: interlude.cycleSeconds,
                cycleEnd: interlude.isRunning ? now.addingTimeInterval(interlude.remaining(at: now)) : nil,
                pausedElapsed: interlude.isRunning ? 0 : interlude.elapsed(at: now)
            )
        }
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults(suiteName: suiteName)?.set(data, forKey: storageKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func loadInterludes() -> [SavedInterlude] {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: storageKey),
              let records = try? JSONDecoder().decode([InterludeRecord].self, from: data) else {
            return []
        }
        return records.map { record in
            var interlude = SavedInterlude(
                id: record.id,
                name: record.name,
                symbolName: record.symbolName,
                tint: DaylightTheme.color(named: record.tintName),
                tintName: record.tintName,
                type: InterludeType(rawValue: record.type) ?? .interval,
                repeatMinutes: record.repeatMinutes,
                durationMinutes: record.durationMinutes,
                runStyle: RunStyle(rawValue: record.runStyle) ?? .manual,
                startMark: StartMark(rawValue: record.startMark) ?? .onTheHour,
                occurrence: Occurrence(rawValue: record.occurrence) ?? .recurring,
                alertsEnabled: record.alertsEnabled ?? (record.notificationPreference != nil && record.notificationPreference != "Off")
            )
            interlude.isEnabled = record.isEnabled
            interlude.didFinishSingle = record.didFinishSingle
            interlude.restorePlayback(
                isRunning: record.isRunning ?? false,
                elapsed: record.pausedElapsed ?? 0,
                cycleEnd: record.cycleEnd
            )
            return interlude
        }
    }
}
