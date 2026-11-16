import SwiftUI

struct InterludeConfiguration: View {
    @Binding var interlude: SavedInterlude
    var onDone: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var nameFocused: Bool
    @State private var showsIconPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    nameFocused = false
                    showsIconPicker = true
                } label: {
                    InterludeDecal(symbolName: interlude.symbolName, tint: interlude.tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Choose icon")

                nameField
                Button("Done", action: onDone)
                    .buttonStyle(.bordered)
                    .foregroundStyle(DaylightTheme.titleColor(for: colorScheme))
            }

            appearanceControls

            Picker("Type", selection: $interlude.type) {
                ForEach(InterludeType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            scheduleControls

            Picker("Run", selection: $interlude.runStyle) {
                ForEach(RunStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)

            if interlude.runStyle == .automatic {
                Picker("Start", selection: $interlude.startMark) {
                    ForEach(StartMark.allCases) { mark in
                        Text(mark.title).tag(mark)
                    }
                }
            }

            Picker("Repeat", selection: $interlude.occurrence) {
                ForEach(Occurrence.allCases) { occurrence in
                    Text(occurrence.rawValue).tag(occurrence)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Alerts", isOn: $interlude.alertsEnabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(interlude.tint.opacity(0.45)), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onChange(of: interlude.repeatMinutes) { _, newValue in
            if let duration = interlude.durationMinutes, duration > newValue {
                interlude.durationMinutes = newValue
            }
        }
        .onChange(of: interlude.occurrence) { _, occurrence in
            if occurrence == .recurring {
                interlude.didFinishSingle = false
            }
        }
        .onChange(of: interlude.alertsEnabled) { _, enabled in
            if enabled {
                InterludeNotifications.requestAccess()
            }
        }
        .sheet(isPresented: $showsIconPicker) {
            IconPicker(selection: $interlude.symbolName, tint: interlude.tint)
        }
    }

    private var nameField: some View {
        TextField("Name", text: $interlude.name)
            .focused($nameFocused)
            .font(.headline)
            .foregroundStyle(DaylightTheme.titleColor(for: colorScheme))
            .tint(.clear)
            .overlay(alignment: .leading) {
                if nameFocused {
                    HStack(spacing: 2) {
                        Text(interlude.name)
                            .font(.headline)
                            .hidden()
                        TitleCursor(color: DaylightTheme.titleColor(for: colorScheme))
                    }
                    .accessibilityHidden(true)
                }
            }
    }

    private var appearanceControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.subheadline)
                .foregroundStyle(DaylightTheme.detailColor(interlude.tint, for: colorScheme))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DaylightTheme.swatches) { swatch in
                        Button {
                            interlude.tintName = swatch.name
                            interlude.tint = swatch.color
                        } label: {
                            Circle()
                                .fill(swatch.color)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if interlude.tintName == swatch.name {
                                        Circle()
                                            .strokeBorder(DaylightTheme.titleColor(for: colorScheme), lineWidth: 2)
                                            .padding(2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(swatch.name)
                        .accessibilityAddTraits(interlude.tintName == swatch.name ? .isSelected : [])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var scheduleControls: some View {
        if interlude.type == .interval {
            Stepper(value: $interlude.repeatMinutes, in: 1...180) {
                Text(InterludeSchedule.everyPhrase(interlude.repeatMinutes))
            }
            Toggle("Duration", isOn: durationEnabled)
            if interlude.durationMinutes != nil {
                Stepper(value: durationBinding, in: 1...max(interlude.repeatMinutes, 1)) {
                    Text(InterludeSchedule.lengthPhrase(interlude.durationMinutes ?? 1))
                }
            }
        } else {
            Stepper(value: timerDuration, in: 1...180) {
                Text(InterludeSchedule.detail(type: .timer, repeatMinutes: 0, durationMinutes: interlude.durationMinutes))
            }
        }
    }

    private var durationEnabled: Binding<Bool> {
        Binding(
            get: { interlude.durationMinutes != nil },
            set: { isOn in
                interlude.durationMinutes = isOn ? min(interlude.durationMinutes ?? 5, max(interlude.repeatMinutes, 1)) : nil
            }
        )
    }

    private var durationBinding: Binding<Int> {
        Binding(
            get: { min(interlude.durationMinutes ?? 1, max(interlude.repeatMinutes, 1)) },
            set: { interlude.durationMinutes = min($0, max(interlude.repeatMinutes, 1)) }
        )
    }

    private var timerDuration: Binding<Int> {
        Binding(
            get: { interlude.durationMinutes ?? 5 },
            set: { interlude.durationMinutes = $0 }
        )
    }
}
private struct TitleCursor: View {
    let color: Color
    @State private var bright = false

    var body: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(color)
            .frame(width: 2, height: 18)
            .opacity(bright ? 1 : 0.2)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    bright = true
                }
            }
    }
}

private struct IconPicker: View {
    @Binding var selection: String
    let tint: Color

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(InterludeSymbol.options, id: \.self) { symbol in
                        Button {
                            selection = symbol
                            dismiss()
                        } label: {
                            Image(systemName: symbol)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(selection == symbol ? .white : DaylightTheme.titleColor(for: colorScheme))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    selection == symbol ? tint : tint.opacity(0.2),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(symbol)
                        .accessibilityAddTraits(selection == symbol ? .isSelected : [])
                    }
                }
                .padding(24)
            }
            .navigationTitle("Icon")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                Button("Done", action: dismiss.callAsFunction)
            }
            .daylightBackground()
        }
    }
}

