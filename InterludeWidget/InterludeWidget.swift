import WidgetKit
import SwiftUI

struct WidgetInterlude: Codable, Identifiable {
    var id: UUID
    var name: String
    var symbolName: String
    var tintName: String
    var detail: String
    var runStyle: String? = nil
    var startMark: Int? = nil
    var isEnabled: Bool? = nil
    var didFinishSingle: Bool? = nil
    var isRunning: Bool? = nil
    var cycleSeconds: TimeInterval? = nil
    var cycleEnd: Date? = nil
    var pausedElapsed: TimeInterval? = nil

    var cycleLength: TimeInterval {
        let seconds = cycleSeconds ?? 60
        return seconds > 0 ? seconds : 60
    }

    func isActivelyRunning(at date: Date) -> Bool {
        guard isRunning == true, let cycleEnd else { return false }
        return cycleEnd > date
    }

    /// Automatic and idle, so the bar counts toward the next start mark.
    func waitsForStart(at date: Date) -> Bool {
        guard runStyle == "Automatic", isEnabled ?? true, didFinishSingle != true, !isActivelyRunning(at: date) else {
            return false
        }
        if isRunning == true {
            return true
        }
        let elapsed = pausedElapsed ?? 0
        return elapsed <= 0 || elapsed >= cycleLength - 0.5
    }

    func nextStart(after date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        components.minute = startMark ?? 0
        components.second = 0
        let mark = calendar.date(from: components) ?? date
        if mark.timeIntervalSince(date) > -1 {
            return mark
        }
        return calendar.date(byAdding: .hour, value: 1, to: mark) ?? mark.addingTimeInterval(3600)
    }

    func bar(at date: Date) -> WidgetBar {
        if isActivelyRunning(at: date), let end = cycleEnd {
            let start = end.addingTimeInterval(-cycleLength)
            if start < end {
                return .live(start...end)
            }
        }
        if waitsForStart(at: date) {
            let end = nextStart(after: date)
            let start = calendarStart(before: end)
            if start < end {
                return .live(start...end)
            }
        }
        let elapsed = min(cycleLength, max(0, pausedElapsed ?? 0))
        let value = elapsed / cycleLength
        return .fraction(value, Self.clock(cycleLength - elapsed))
    }

    /// When the widget should reload so a countdown can become a running cycle, or the reverse.
    func refreshDate(after date: Date) -> Date? {
        if isActivelyRunning(at: date), let cycleEnd, cycleEnd > date {
            return cycleEnd
        }
        guard waitsForStart(at: date) else { return nil }
        let start = nextStart(after: date)
        if start.timeIntervalSince(date) < 1 {
            return date.addingTimeInterval(2)
        }
        return start
    }

    private func calendarStart(before end: Date) -> Date {
        Calendar.current.date(byAdding: .hour, value: -1, to: end) ?? end.addingTimeInterval(-3600)
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

enum WidgetBar {
    case live(ClosedRange<Date>)
    case fraction(Double, String)
}

struct InterludeEntry: TimelineEntry {
    let date: Date
    let interludes: [WidgetInterlude]
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> InterludeEntry {
        InterludeEntry(date: .now, interludes: Provider.samples)
    }

    func getSnapshot(in context: Context, completion: @escaping (InterludeEntry) -> Void) {
        let interludes = loadInterludes()
        completion(InterludeEntry(date: .now, interludes: interludes.isEmpty ? Provider.samples : interludes))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<InterludeEntry>) -> Void) {
        let now = Date()
        let interludes = loadInterludes()
        let entry = InterludeEntry(date: now, interludes: interludes)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh(interludes, after: now))))
    }

    private func nextRefresh(_ interludes: [WidgetInterlude], after now: Date) -> Date {
        let fallback = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        let dates = interludes.compactMap { $0.refreshDate(after: now) }.filter { $0 > now }
        guard let soonest = dates.min() else { return fallback }
        return min(soonest, fallback)
    }

    private func loadInterludes() -> [WidgetInterlude] {
        guard let data = UserDefaults(suiteName: "group.com.loganjasin.Interlude")?.data(forKey: "interludes"),
              let interludes = try? JSONDecoder().decode([WidgetInterlude].self, from: data) else {
            return []
        }
        return interludes
    }

    static let samples: [WidgetInterlude] = [
        WidgetInterlude(id: UUID(), name: "Look away", symbolName: "eye", tintName: "sky", detail: "Every 20 min", cycleSeconds: 1200),
        WidgetInterlude(id: UUID(), name: "Breathing", symbolName: "lungs", tintName: "lilac", detail: "Every hour \u{00B7} 1 min", cycleSeconds: 60),
        WidgetInterlude(id: UUID(), name: "Take a break", symbolName: "cup.and.saucer", tintName: "amber", detail: "5 min timer", cycleSeconds: 300),
        WidgetInterlude(id: UUID(), name: "Drink water", symbolName: "drop.fill", tintName: "water", detail: "Every hour \u{00B7} On the hour", runStyle: "Automatic", startMark: 0, isEnabled: true, didFinishSingle: false, isRunning: false, cycleSeconds: 3600),
        WidgetInterlude(id: UUID(), name: "Stretch", symbolName: "figure.flexibility", tintName: "rose", detail: "Every 30 min", cycleSeconds: 1800),
        WidgetInterlude(id: UUID(), name: "Stand up", symbolName: "figure.walk", tintName: "leaf", detail: "Every 45 min", cycleSeconds: 2700),
    ]
}

struct InterludeWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    var entry: InterludeEntry

    var body: some View {
        Group {
            if entry.interludes.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:
            if let interlude = entry.interludes.first {
                featured(interlude)
            }
        case .systemMedium:
            rows(Array(entry.interludes.prefix(3)))
        case .systemLarge:
            rows(Array(entry.interludes.prefix(6)))
        default:
            fittedRows
        }
    }

    private var fittedRows: some View {
        GeometryReader { proxy in
            let count = max(1, Int(proxy.size.height / 56))
            rows(Array(entry.interludes.prefix(count)))
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if let url = WidgetAddLink.url {
            Link(destination: url) {
                Text("Add new interlude")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(colorScheme == .dark ? WidgetPalette.deepSea : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        colorScheme == .dark ? WidgetPalette.mist : WidgetPalette.pine,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
            }
            .accessibilityLabel("Add new interlude")
        }
    }

    private func featured(_ interlude: WidgetInterlude) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: interlude.symbolName)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(tint(interlude.tintName), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(interlude.name)
                .font(.headline)
                .foregroundStyle(titleColor)
                .lineLimit(2)
            Text(interlude.detail)
                .font(.caption)
                .foregroundStyle(tint(interlude.tintName))
                .lineLimit(2)
            Spacer(minLength: 4)
            progress(interlude, prominent: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func rows(_ interludes: [WidgetInterlude]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(interludes) { interlude in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Image(systemName: interlude.symbolName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(tint(interlude.tintName), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(interlude.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(titleColor)
                                .lineLimit(1)
                            Text(interlude.detail)
                                .font(.caption2)
                                .foregroundStyle(tint(interlude.tintName))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    progress(interlude, prominent: false)
                }
            }
        }
    }

    private func progress(_ interlude: WidgetInterlude, prominent: Bool) -> some View {
        let labelFont: Font = prominent ? .subheadline.monospacedDigit() : .caption2.monospacedDigit()
        return HStack(spacing: 8) {
            switch interlude.bar(at: entry.date) {
            case .live(let range):
                ProgressView(timerInterval: range, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(barTint(interlude.tintName))
                Text(range.upperBound, style: .timer)
                    .font(labelFont)
                    .foregroundStyle(barTint(interlude.tintName))
                    .lineLimit(1)
            case .fraction(let value, let label):
                ProgressView(value: value)
                    .tint(barTint(interlude.tintName))
                Text(label)
                    .font(labelFont)
                    .foregroundStyle(barTint(interlude.tintName))
                    .lineLimit(1)
            }
        }
    }

    private var titleColor: Color {
        colorScheme == .dark ? WidgetPalette.mist : WidgetPalette.pine
    }

    private func tint(_ name: String) -> Color {
        WidgetPalette.color(named: name)
    }

    private func barTint(_ name: String) -> Color {
        let base = WidgetPalette.color(named: name)
        return colorScheme == .dark ? base.mix(with: .white, by: 0.62) : base
    }
}

enum WidgetAddLink {
    static var url: URL? {
        var components = URLComponents()
        components.scheme = "interlude"
        components.host = "add"
        return components.url
    }
}

private enum WidgetPalette {
    static let pine = Color(red: 0.09, green: 0.38, blue: 0.34)
    static let mist = Color(red: 0.72, green: 0.90, blue: 0.84)
    static let cream = Color(red: 0.99, green: 0.94, blue: 0.86)
    static let deepSea = Color(red: 0.07, green: 0.16, blue: 0.18)
    static let dusk = Color(red: 0.18, green: 0.12, blue: 0.24)

    static func color(named name: String) -> Color {
        switch name {
        case "leaf": Color(red: 0.16, green: 0.62, blue: 0.40)
        case "amber": Color(red: 0.90, green: 0.52, blue: 0.16)
        case "sky": Color(red: 0.24, green: 0.48, blue: 0.86)
        case "water": Color(red: 0.12, green: 0.62, blue: 0.74)
        case "rose": Color(red: 0.78, green: 0.36, blue: 0.52)
        case "lilac": Color(red: 0.55, green: 0.40, blue: 0.78)
        case "tomato": Color(red: 0.82, green: 0.35, blue: 0.28)
        default: pine
        }
    }

    static func background(for colorScheme: ColorScheme) -> LinearGradient {
        let colors = colorScheme == .dark ? [deepSea, dusk] : [cream, mist]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct InterludeWidget: Widget {
    let kind: String = "InterludeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            InterludeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
        }
        .configurationDisplayName("Interludes")
        .description("Your interludes on the Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

private struct WidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        WidgetPalette.background(for: colorScheme)
    }
}

#Preview("Empty", as: .systemSmall) {
    InterludeWidget()
} timeline: {
    InterludeEntry(date: .now, interludes: [])
}

#Preview(as: .systemMedium) {
    InterludeWidget()
} timeline: {
    InterludeEntry(date: .now, interludes: [
        Provider.samples[3],
        Provider.samples[0],
        Provider.samples[2],
    ])
}
