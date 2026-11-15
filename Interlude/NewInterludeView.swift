import SwiftUI

struct NewInterludeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var onAdd: (SavedInterlude) -> Void

    @State private var configuration: AddConfiguration?

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configure one or more interludes")
                        .font(.headline)
                        .foregroundStyle(DaylightTheme.titleColor(for: colorScheme))

                    ForEach(InterludeLibrary.suggestions) { template in
                        Button {
                            configuration = .preset(template.id)
                        } label: {
                            SuggestionCard(
                                name: template.name,
                                detail: template.detail,
                                symbolName: template.symbolName,
                                tint: template.tint
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        configuration = .custom
                    } label: {
                        SuggestionCard(
                            name: "Custom interlude",
                            detail: "Name, interval, and duration",
                            symbolName: "slider.horizontal.3",
                            tint: DaylightTheme.pine
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
                .frame(maxWidth: 880)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .bottom)
            }
        }
        .navigationTitle("Add an interlude")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar(.visible, for: .navigationBar)
        .daylightBackground()
        .navigationDestination(item: $configuration) { route in
            CustomInterludeEditor(template: route.template) { add($0) }
        }
    }

    private func add(_ interlude: SavedInterlude) {
        onAdd(interlude)
        dismiss()
    }
}

private enum AddConfiguration: Hashable {
    case custom
    case preset(String)

    var template: InterludeTemplate? {
        switch self {
        case .custom:
            nil
        case .preset(let name):
            InterludeLibrary.suggestions.first { $0.id == name }
        }
    }
}

struct CustomInterludeEditor: View {
    @Environment(\.colorScheme) private var colorScheme

    var onAdd: (SavedInterlude) -> Void
    private let symbolName: String?
    private let tint: Color?
    private let screenTitle: String

    @State private var name: String
    @State private var type: InterludeType
    @State private var repeatMinutes: Int
    @State private var includesDuration: Bool
    @State private var durationMinutes: Int

    init(template: InterludeTemplate? = nil, onAdd: @escaping (SavedInterlude) -> Void) {
        self.onAdd = onAdd
        symbolName = template?.symbolName
        tint = template?.tint
        screenTitle = template?.name ?? "Custom interlude"
        let repeatValue = template?.repeatMinutes ?? 25
        _name = State(initialValue: template?.name ?? "")
        _type = State(initialValue: template?.type ?? .interval)
        _repeatMinutes = State(initialValue: repeatValue > 0 ? repeatValue : 25)
        _includesDuration = State(initialValue: template?.type != .timer && template?.durationMinutes != nil)
        _durationMinutes = State(initialValue: template?.durationMinutes ?? 5)
    }

    var body: some View {
        Form {
            TextField("Name", text: $name)
            Picker("Type", selection: $type) {
                ForEach(InterludeType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            if type == .interval {
                Stepper(value: $repeatMinutes, in: 1...180) {
                    Text(InterludeSchedule.everyPhrase(repeatMinutes))
                }
                Toggle("Duration", isOn: $includesDuration)
                if includesDuration {
                    Stepper(
                        value: Binding(
                            get: { min(durationMinutes, repeatMinutes) },
                            set: { durationMinutes = min($0, repeatMinutes) }
                        ),
                        in: 1...max(repeatMinutes, 1)
                    ) {
                        Text(InterludeSchedule.lengthPhrase(min(durationMinutes, repeatMinutes)))
                    }
                }
            } else {
                Stepper(value: $durationMinutes, in: 1...180) {
                    Text(InterludeSchedule.detail(type: .timer, repeatMinutes: 0, durationMinutes: durationMinutes))
                }
            }
        }
        .onChange(of: repeatMinutes) { _, newValue in
            if durationMinutes > newValue {
                durationMinutes = newValue
            }
        }
        .navigationTitle(screenTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    onAdd(
                        SavedInterlude(
                            name: trimmed,
                            symbolName: symbolName ?? type.symbolName,
                            tint: tint ?? DaylightTheme.pine,
                            type: type,
                            repeatMinutes: type == .interval ? repeatMinutes : 0,
                            durationMinutes: type == .timer ? durationMinutes : (includesDuration ? min(durationMinutes, repeatMinutes) : nil)
                        )
                    )
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .daylightBackground()
        .tint(colorScheme == .dark ? DaylightTheme.mist : DaylightTheme.pine)
    }
}

#Preview("Add") {
    NavigationStack {
        NewInterludeView { _ in }
    }
}

#Preview("Custom") {
    NavigationStack {
        CustomInterludeEditor { _ in }
    }
}

#Preview("Eat lunch") {
    NavigationStack {
        CustomInterludeEditor(template: InterludeLibrary.suggestions.first { $0.name == "Eat lunch" }) { _ in }
    }
}
