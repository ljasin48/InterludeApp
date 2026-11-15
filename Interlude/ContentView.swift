import SwiftUI

enum DaylightTheme {
    static let pine = Color(red: 0.09, green: 0.38, blue: 0.34)
    static let mist = Color(red: 0.72, green: 0.90, blue: 0.84)
    static let cream = Color(red: 0.99, green: 0.94, blue: 0.86)
    static let apricot = Color(red: 0.96, green: 0.78, blue: 0.58)
    static let deepSea = Color(red: 0.07, green: 0.16, blue: 0.18)
    static let dusk = Color(red: 0.18, green: 0.12, blue: 0.24)

    static let leaf = Color(red: 0.16, green: 0.62, blue: 0.40)
    static let amber = Color(red: 0.90, green: 0.52, blue: 0.16)
    static let sky = Color(red: 0.24, green: 0.48, blue: 0.86)
    static let water = Color(red: 0.12, green: 0.62, blue: 0.74)
    static let rose = Color(red: 0.78, green: 0.36, blue: 0.52)
    static let lilac = Color(red: 0.55, green: 0.40, blue: 0.78)
    static let tomato = Color(red: 0.82, green: 0.35, blue: 0.28)

    static func backgroundColors(for colorScheme: ColorScheme) -> [Color] {
        if colorScheme == .dark {
            return [deepSea, dusk]
        }
        return [cream, apricot.opacity(0.55), mist]
    }

    static func titleColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? mist : pine
    }
}

enum InterludeKind: String, CaseIterable, Identifiable {
    case interval = "Interval"
    case timer = "Timer"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .interval: "repeat"
        case .timer: "timer"
        }
    }
}

struct SavedInterlude: Identifiable {
    let id: UUID
    var name: String
    var symbolName: String
    var tint: Color
    var kind: InterludeKind
    /// How often an interval repeats. Unused for timers.
    var repeatMinutes: Int
    /// How long the interlude lasts. Required for timers, optional for intervals.
    var durationMinutes: Int?

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        tint: Color,
        kind: InterludeKind,
        repeatMinutes: Int = 0,
        durationMinutes: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.tint = tint
        self.kind = kind
        self.repeatMinutes = repeatMinutes
        self.durationMinutes = durationMinutes
    }

    var isRunning = false
    private var storedElapsed: TimeInterval = 0
    private var segmentStartedAt: Date?

    var detail: String {
        InterludeSchedule.detail(kind: kind, repeatMinutes: repeatMinutes, durationMinutes: durationMinutes)
    }

    /// Countdown length. A set duration wins; otherwise an interval counts down its repeat.
    var cycleSeconds: TimeInterval {
        let minutes = durationMinutes ?? max(repeatMinutes, 1)
        return TimeInterval(max(minutes, 1) * 60)
    }

    func elapsed(at date: Date) -> TimeInterval {
        var total = storedElapsed
        if isRunning, let segmentStartedAt {
            total += max(0, date.timeIntervalSince(segmentStartedAt))
        }
        return min(cycleSeconds, total)
    }

    func remaining(at date: Date) -> TimeInterval {
        max(0, cycleSeconds - elapsed(at: date))
    }

    func progress(at date: Date) -> Double {
        guard cycleSeconds > 0 else { return 0 }
        return min(1, elapsed(at: date) / cycleSeconds)
    }

    var hasStarted: Bool {
        isRunning || storedElapsed > 0
    }

    mutating func play(at date: Date) {
        if elapsed(at: date) >= cycleSeconds {
            storedElapsed = 0
        } else {
            storedElapsed = elapsed(at: date)
        }
        isRunning = true
        segmentStartedAt = date
    }

    mutating func pause(at date: Date) {
        storedElapsed = elapsed(at: date)
        isRunning = false
        segmentStartedAt = nil
    }

    mutating func reset() {
        storedElapsed = 0
        isRunning = false
        segmentStartedAt = nil
    }

    mutating func completeCycle(at date: Date) {
        if kind == .interval {
            storedElapsed = 0
            segmentStartedAt = date
            isRunning = true
        } else {
            storedElapsed = cycleSeconds
            isRunning = false
            segmentStartedAt = nil
        }
    }
}

enum InterludeSchedule {
    static func everyPhrase(_ minutes: Int) -> String {
        if minutes == 1 { return "Every minute" }
        if minutes == 60 { return "Every hour" }
        return "Every \(minutes) min"
    }

    static func lengthPhrase(_ minutes: Int) -> String {
        if minutes == 1 { return "1 min" }
        if minutes == 60 { return "1 hour" }
        return "\(minutes) min"
    }

    static func detail(kind: InterludeKind, repeatMinutes: Int, durationMinutes: Int?) -> String {
        switch kind {
        case .interval:
            let every = everyPhrase(repeatMinutes)
            guard let durationMinutes else { return every }
            return "\(every) \u{00B7} \(lengthPhrase(durationMinutes))"
        case .timer:
            let minutes = durationMinutes ?? 1
            if minutes == 1 { return "1 min timer" }
            if minutes == 60 { return "1 hour timer" }
            return "\(minutes) min timer"
        }
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

struct InterludeTemplate: Identifiable {
    let name: String
    let symbolName: String
    let tint: Color
    let kind: InterludeKind
    let repeatMinutes: Int
    let durationMinutes: Int?

    var id: String { name }

    var detail: String {
        InterludeSchedule.detail(kind: kind, repeatMinutes: repeatMinutes, durationMinutes: durationMinutes)
    }

    func makeInterlude() -> SavedInterlude {
        SavedInterlude(
            name: name,
            symbolName: symbolName,
            tint: tint,
            kind: kind,
            repeatMinutes: repeatMinutes,
            durationMinutes: durationMinutes
        )
    }
}

enum InterludeLibrary {
    static let suggestions: [InterludeTemplate] = [
        InterludeTemplate(name: "Stand up / walk", symbolName: "figure.walk", tint: DaylightTheme.leaf, kind: .interval, repeatMinutes: 45, durationMinutes: nil),
        InterludeTemplate(name: "Take a break", symbolName: "cup.and.saucer", tint: DaylightTheme.amber, kind: .timer, repeatMinutes: 0, durationMinutes: 5),
        InterludeTemplate(name: "Look away", symbolName: "eye", tint: DaylightTheme.sky, kind: .interval, repeatMinutes: 20, durationMinutes: nil),
        InterludeTemplate(name: "Breathing", symbolName: "lungs", tint: DaylightTheme.lilac, kind: .interval, repeatMinutes: 60, durationMinutes: 1),
        InterludeTemplate(name: "Drink water", symbolName: "drop.fill", tint: DaylightTheme.water, kind: .interval, repeatMinutes: 60, durationMinutes: nil),
        InterludeTemplate(name: "Eat lunch", symbolName: "fork.knife", tint: DaylightTheme.tomato, kind: .timer, repeatMinutes: 0, durationMinutes: 45),
        InterludeTemplate(name: "Stretch", symbolName: "figure.flexibility", tint: DaylightTheme.rose, kind: .interval, repeatMinutes: 30, durationMinutes: nil),
    ]
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var interludes: [SavedInterlude]
    @State private var isAdding = false

    init() {
        _interludes = State(initialValue: [])
    }

    fileprivate init(previewInterludes: [SavedInterlude]) {
        _interludes = State(initialValue: previewInterludes)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                GeometryReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if interludes.isEmpty {
                                emptyState
                            }
                            interludeColumn
                        }
                        .padding(24)
                        .frame(maxWidth: 880)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: proxy.size.height, alignment: .bottom)
                    }
                }
            }
            .daylightBackground()
            .tint(DaylightTheme.pine)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isAdding) {
                NewInterludeView {
                    interludes.append($0)
                    isAdding = false
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Interlude")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(DaylightTheme.titleColor(for: colorScheme))
            Text("Intervals and timers for the workday.")
                .font(.title3)
                .foregroundStyle(DaylightTheme.titleColor(for: colorScheme).opacity(0.72))
        }
        .accessibilityElement(children: .combine)
    }

    private var addButton: some View {
        Button {
            isAdding = true
        } label: {
            SuggestionCard(
                name: "Add interlude",
                detail: "Choose a preset or make your own",
                symbolName: "plus",
                tint: DaylightTheme.pine
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        Text("No interludes yet. Add one from a suggestion, or make your own.")
            .font(.body)
            .foregroundStyle(DaylightTheme.titleColor(for: colorScheme).opacity(0.72))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var interludeColumn: some View {
        Group {
            if interludes.contains(where: \.isRunning) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    interludeStack(at: context.date)
                        .onChange(of: context.date) { _, date in
                            advancePlayback(to: date)
                        }
                }
            } else {
                interludeStack(at: .now)
            }
        }
    }

    private func interludeStack(at date: Date) -> some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 16) {
                ForEach(interludes) { interlude in
                    InterludeCard(
                        interlude: interlude,
                        now: date,
                        onPlayPause: { togglePlayback(interlude.id, at: .now) },
                        onReset: { resetPlayback(interlude.id) }
                    )
                }
                addButton
            }
        }
    }

    private func togglePlayback(_ id: UUID, at date: Date) {
        guard let index = interludes.firstIndex(where: { $0.id == id }) else { return }
        if interludes[index].isRunning {
            interludes[index].pause(at: date)
        } else {
            interludes[index].play(at: date)
        }
    }

    private func resetPlayback(_ id: UUID) {
        guard let index = interludes.firstIndex(where: { $0.id == id }) else { return }
        interludes[index].reset()
    }

    private func advancePlayback(to date: Date) {
        for index in interludes.indices where interludes[index].isRunning && interludes[index].remaining(at: date) <= 0 {
            interludes[index].completeCycle(at: date)
        }
    }
}

struct SuggestionCard: View {
    let name: String
    let detail: String
    let symbolName: String
    let tint: Color

    var body: some View {
        HStack(spacing: 16) {
            InterludeDecal(symbolName: symbolName, tint: tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(tint)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .glassEffect(.regular.tint(tint.opacity(0.45)), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(.interaction, RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct InterludeCard: View {
    let interlude: SavedInterlude
    let now: Date
    var onPlayPause: () -> Void
    var onReset: () -> Void

    private var remainingText: String {
        InterludeSchedule.clock(interlude.remaining(at: now))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                InterludeDecal(symbolName: interlude.symbolName, tint: interlude.tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text(interlude.name)
                        .font(.headline)
                    Text(interlude.detail)
                        .font(.subheadline)
                        .foregroundStyle(interlude.tint)
                }

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    Button(action: onPlayPause) {
                        Image(systemName: interlude.isRunning ? "pause.fill" : "play.fill")
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel(interlude.isRunning ? "Pause" : "Play")

                    Button(action: onReset) {
                        Image(systemName: "stop.fill")
                            .frame(width: 36, height: 36)
                    }
                    .disabled(!interlude.hasStarted)
                    .accessibilityLabel("Stop and reset")
                }
                .buttonStyle(.bordered)
                .tint(interlude.tint)
                .font(.body.weight(.semibold))
            }

            HStack(spacing: 12) {
                ProgressView(value: interlude.progress(at: now))
                    .tint(interlude.tint)
                    .accessibilityLabel("Time remaining")
                    .accessibilityValue(remainingText)
                Text(remainingText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(interlude.tint)
                    .accessibilityHidden(true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(interlude.tint.opacity(0.45)), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct InterludeDecal: View {
    let symbolName: String
    let tint: Color

    var body: some View {
        Image(systemName: symbolName)
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct DaylightBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.background {
            LinearGradient(
                colors: DaylightTheme.backgroundColors(for: colorScheme),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

extension View {
    func daylightBackground() -> some View {
        modifier(DaylightBackground())
    }
}

#Preview("Empty") {
    ContentView()
}

#Preview("With interludes") {
    ContentView(previewInterludes: [
        SavedInterlude(name: "Look away", symbolName: "eye", tint: DaylightTheme.sky, kind: .interval, repeatMinutes: 20),
        SavedInterlude(name: "Breathing", symbolName: "lungs", tint: DaylightTheme.lilac, kind: .interval, repeatMinutes: 60, durationMinutes: 1),
        SavedInterlude(name: "Take a break", symbolName: "cup.and.saucer", tint: DaylightTheme.amber, kind: .timer, durationMinutes: 5),
    ])
}


