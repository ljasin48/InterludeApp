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
        colorScheme == .dark ? [deepSea, dusk] : [cream, apricot.opacity(0.55), mist]
    }

    static func titleColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? mist : pine
    }

    static func detailColor(_ tint: Color, for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? tint.mix(with: .white, by: 0.62) : tint
    }
}

enum InterludeType: String, CaseIterable, Identifiable {
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
    var type: InterludeType
    /// How often an interval repeats. Unused for timers.
    var repeatMinutes: Int
    /// How long the interlude lasts. Required for timers, optional for intervals.
    var durationMinutes: Int?

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        tint: Color,
        type: InterludeType,
        repeatMinutes: Int = 0,
        durationMinutes: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.tint = tint
        self.type = type
        self.repeatMinutes = repeatMinutes
        self.durationMinutes = durationMinutes
    }

    var isRunning = false
    var isEnabled = true
    var snoozedUntil: Date?
    private var storedElapsed: TimeInterval = 0
    private var segmentStartedAt: Date?

    var detail: String {
        InterludeSchedule.detail(type: type, repeatMinutes: repeatMinutes, durationMinutes: durationMinutes)
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

    func isSnoozed(at date: Date) -> Bool {
        guard let snoozedUntil else { return false }
        return date < snoozedUntil
    }

    func isAvailable(at date: Date) -> Bool {
        isEnabled && !isSnoozed(at: date)
    }

    mutating func setEnabled(_ enabled: Bool, at date: Date) {
        isEnabled = enabled
        snoozedUntil = nil
        if !enabled, isRunning {
            pause(at: date)
        }
    }

    mutating func snooze(for minutes: Int, at date: Date) {
        isEnabled = true
        snoozedUntil = date.addingTimeInterval(TimeInterval(minutes * 60))
        if isRunning {
            pause(at: date)
        }
    }

    mutating func endSnooze() {
        snoozedUntil = nil
    }

    mutating func play(at date: Date) {
        guard isAvailable(at: date) else { return }
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
        if type == .interval {
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

    static func detail(type: InterludeType, repeatMinutes: Int, durationMinutes: Int?) -> String {
        switch type {
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
    let type: InterludeType
    let repeatMinutes: Int
    let durationMinutes: Int?

    var id: String { name }

    var detail: String {
        InterludeSchedule.detail(type: type, repeatMinutes: repeatMinutes, durationMinutes: durationMinutes)
    }

    func makeInterlude() -> SavedInterlude {
        SavedInterlude(
            name: name,
            symbolName: symbolName,
            tint: tint,
            type: type,
            repeatMinutes: repeatMinutes,
            durationMinutes: durationMinutes
        )
    }
}

enum InterludeLibrary {
    static let suggestions: [InterludeTemplate] = [
        InterludeTemplate(name: "Stand up / walk", symbolName: "figure.walk", tint: DaylightTheme.leaf, type: .interval, repeatMinutes: 45, durationMinutes: nil),
        InterludeTemplate(name: "Take a break", symbolName: "cup.and.saucer", tint: DaylightTheme.amber, type: .timer, repeatMinutes: 0, durationMinutes: 5),
        InterludeTemplate(name: "Look away", symbolName: "eye", tint: DaylightTheme.sky, type: .interval, repeatMinutes: 20, durationMinutes: nil),
        InterludeTemplate(name: "Breathing", symbolName: "lungs", tint: DaylightTheme.lilac, type: .interval, repeatMinutes: 60, durationMinutes: 1),
        InterludeTemplate(name: "Drink water", symbolName: "drop.fill", tint: DaylightTheme.water, type: .interval, repeatMinutes: 60, durationMinutes: nil),
        InterludeTemplate(name: "Eat lunch", symbolName: "fork.knife", tint: DaylightTheme.tomato, type: .timer, repeatMinutes: 0, durationMinutes: 45),
        InterludeTemplate(name: "Stretch", symbolName: "figure.flexibility", tint: DaylightTheme.rose, type: .interval, repeatMinutes: 30, durationMinutes: nil),
    ]
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var interludes: [SavedInterlude]
    @State private var isAdding: Bool

    init() {
        _interludes = State(initialValue: [])
        _isAdding = State(initialValue: true)
    }

    fileprivate init(previewInterludes: [SavedInterlude]) {
        _interludes = State(initialValue: previewInterludes)
        _isAdding = State(initialValue: previewInterludes.isEmpty)
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
                            } else {
                                interludeColumn
                            }
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
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Interlude")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(DaylightTheme.titleColor(for: colorScheme))
                Text("Intervals and timers for the workday.")
                    .font(.title3)
                    .foregroundStyle(DaylightTheme.titleColor(for: colorScheme).opacity(0.72))
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 12)

            Button {
                isAdding = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DaylightTheme.titleColor(for: colorScheme))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Add interlude")
        }
    }

    private var emptyState: some View {
        Text("No interludes yet.")
            .font(.body)
            .foregroundStyle(DaylightTheme.titleColor(for: colorScheme).opacity(0.72))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tracksTime: Bool {
        interludes.contains { $0.isRunning || $0.snoozedUntil != nil }
    }

    private var interludeColumn: some View {
        Group {
            if tracksTime {
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
        VStack(spacing: 16) {
            ForEach(interludes) { interlude in
                GlassEffectContainer(spacing: 12) {
                    InterludeCard(
                        interlude: interlude,
                        now: date,
                        onPlayPause: { togglePlayback(interlude.id, at: .now) },
                        onReset: { resetPlayback(interlude.id) },
                        onSetEnabled: { setEnabled(interlude.id, enabled: $0, at: .now) },
                        onSnooze: { snooze(interlude.id, minutes: $0, at: .now) },
                        onEndSnooze: { endSnooze(interlude.id) },
                        onRemove: { removeInterlude(interlude.id) }
                    )
                }
                .swipeToRemove { removeInterlude(interlude.id) }
            }
        }
    }

    private func togglePlayback(_ id: UUID, at date: Date) {
        guard let index = interludes.firstIndex(where: { $0.id == id }) else { return }
        guard interludes[index].isAvailable(at: date) else { return }
        if interludes[index].isRunning {
            interludes[index].pause(at: date)
        } else {
            interludes[index].play(at: date)
        }
    }

    private func setEnabled(_ id: UUID, enabled: Bool, at date: Date) {
        guard let index = interludes.firstIndex(where: { $0.id == id }) else { return }
        interludes[index].setEnabled(enabled, at: date)
    }

    private func snooze(_ id: UUID, minutes: Int, at date: Date) {
        guard let index = interludes.firstIndex(where: { $0.id == id }) else { return }
        interludes[index].snooze(for: minutes, at: date)
    }

    private func endSnooze(_ id: UUID) {
        guard let index = interludes.firstIndex(where: { $0.id == id }) else { return }
        interludes[index].endSnooze()
    }

    private func removeInterlude(_ id: UUID) {
        withAnimation(.snappy) {
            interludes.removeAll { $0.id == id }
        }
    }

    private func resetPlayback(_ id: UUID) {
        guard let index = interludes.firstIndex(where: { $0.id == id }) else { return }
        interludes[index].reset()
    }

    private func advancePlayback(to date: Date) {
        for index in interludes.indices {
            if let until = interludes[index].snoozedUntil, date >= until {
                interludes[index].endSnooze()
            }
            if interludes[index].isRunning && interludes[index].remaining(at: date) <= 0 {
                interludes[index].completeCycle(at: date)
            }
        }
    }
}

struct SuggestionCard: View {
    @Environment(\.colorScheme) private var colorScheme

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
                    .foregroundStyle(DaylightTheme.detailColor(tint, for: colorScheme))
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
    @Environment(\.colorScheme) private var colorScheme

    let interlude: SavedInterlude
    let now: Date
    var onPlayPause: () -> Void
    var onReset: () -> Void
    var onSetEnabled: (Bool) -> Void
    var onSnooze: (Int) -> Void
    var onEndSnooze: () -> Void
    var onRemove: () -> Void

    private var isAvailable: Bool {
        interlude.isAvailable(at: now)
    }

    private var remainingText: String {
        InterludeSchedule.clock(interlude.remaining(at: now))
    }

    private var statusDetail: String {
        if !interlude.isEnabled {
            return "Off \u{00B7} \(interlude.detail)"
        }
        if interlude.isSnoozed(at: now), let until = interlude.snoozedUntil {
            let remaining = InterludeSchedule.clock(until.timeIntervalSince(now))
            return "Snoozed \u{00B7} \(remaining) \u{00B7} \(interlude.detail)"
        }
        return interlude.detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                InterludeDecal(symbolName: interlude.symbolName, tint: interlude.tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text(interlude.name)
                        .font(.headline)
                    Text(statusDetail)
                        .font(.subheadline)
                        .foregroundStyle(DaylightTheme.detailColor(interlude.tint, for: colorScheme))
                }

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    Button(action: onPlayPause) {
                        Image(systemName: interlude.isRunning ? "pause.fill" : "play.fill")
                            .frame(width: 36, height: 36)
                    }
                    .disabled(!isAvailable)
                    .accessibilityLabel(interlude.isRunning ? "Pause" : "Play")

                    Button(action: onReset) {
                        Image(systemName: "stop.fill")
                            .frame(width: 36, height: 36)
                    }
                    .disabled(!interlude.hasStarted)
                    .accessibilityLabel("Stop and reset")

                    Menu {
                        if interlude.isEnabled {
                            Button("Turn off", systemImage: "power") { onSetEnabled(false) }
                        } else {
                            Button("Turn on", systemImage: "power") { onSetEnabled(true) }
                        }
                        if interlude.isSnoozed(at: now) {
                            Button("End snooze", systemImage: "alarm") { onEndSnooze() }
                        }
                        Button("Snooze 15 min", systemImage: "moon.zzz") { onSnooze(15) }
                        Button("Snooze 1 hour", systemImage: "moon.zzz") { onSnooze(60) }
                    } label: {
                        Image(systemName: availabilitySymbol)
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("Snooze or turn off")
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
        .glassEffect(.regular.tint(interlude.tint.opacity(isAvailable ? 0.45 : 0.2)), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .opacity(isAvailable ? 1 : 0.72)
        .accessibilityAction(named: "Remove") { onRemove() }
    }

    private var availabilitySymbol: String {
        if !interlude.isEnabled { return "power" }
        if interlude.isSnoozed(at: now) { return "moon.zzz.fill" }
        return "moon.zzz"
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

    func swipeToRemove(perform onRemove: @escaping () -> Void) -> some View {
        modifier(SwipeToRemoveModifier(onRemove: onRemove))
    }
}

private struct SwipeToRemoveModifier: ViewModifier {
    var onRemove: () -> Void
    @State private var offset: CGFloat = 0
    @State private var restingOffset: CGFloat = 0
    @State private var cardWidth: CGFloat = 0
    @State private var cardHeight: CGFloat = 0

    private let buttonWidth: CGFloat = 76
    private let buttonGap: CGFloat = 8

    private var openOffset: CGFloat { -(buttonWidth + buttonGap) }

    private var revealedWidth: CGFloat {
        min(buttonWidth, max(0, -offset - buttonGap))
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            Button(action: delete) {
                Image(systemName: "trash")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: buttonWidth, height: cardHeight)
                    .background(.red, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(width: revealedWidth, height: cardHeight, alignment: .trailing)
            .clipped()
            .disabled(revealedWidth < buttonWidth - 1)
            .accessibilityLabel("Remove")

            content
                .onGeometryChange(for: CGSize.self) { proxy in
                    proxy.size
                } action: { _, size in
                    cardWidth = size.width
                    cardHeight = size.height
                }
                .offset(x: offset)
                .simultaneousGesture(drag)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func delete() {
        let travel = -(max(cardWidth, 1) + buttonWidth)
        withAnimation(.easeOut(duration: 0.18)) {
            offset = travel
        } completion: {
            onRemove()
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                let width = value.translation.width
                guard abs(width) > abs(value.translation.height) else { return }
                let raw = restingOffset + width
                guard raw < 0 || restingOffset < 0 else { return }
                offset = resisted(raw)
            }
            .onEnded { value in
                let width = value.translation.width
                guard abs(width) > abs(value.translation.height) else {
                    withAnimation(.snappy) { offset = restingOffset }
                    return
                }
                let raw = restingOffset + width
                if raw < openOffset - 64 {
                    delete()
                    return
                }
                let opened = raw < openOffset / 2
                withAnimation(.snappy) {
                    restingOffset = opened ? openOffset : 0
                    offset = restingOffset
                }
            }
    }

    private func resisted(_ raw: CGFloat) -> CGFloat {
        let limited = min(0, raw)
        guard limited < openOffset else { return limited }
        let extra = limited - openOffset
        return openOffset + extra * 0.28
    }
}

#Preview("Empty") {
    ContentView()
}

#Preview("With interludes") {
    ContentView(previewInterludes: [
        SavedInterlude(name: "Look away", symbolName: "eye", tint: DaylightTheme.sky, type: .interval, repeatMinutes: 20),
        SavedInterlude(name: "Breathing", symbolName: "lungs", tint: DaylightTheme.lilac, type: .interval, repeatMinutes: 60, durationMinutes: 1),
        SavedInterlude(name: "Take a break", symbolName: "cup.and.saucer", tint: DaylightTheme.amber, type: .timer, durationMinutes: 5),
    ])
}


