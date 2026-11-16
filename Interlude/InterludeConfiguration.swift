import SwiftUI

struct InterludeConfiguration: View {
    @Binding var interlude: SavedInterlude
    var onDone: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                TextField("Name", text: $interlude.name)
                    .font(.headline)
                    .foregroundStyle(DaylightTheme.titleColor(for: colorScheme))
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

            Picker("Notifications", selection: $interlude.notificationPreference) {
                ForEach(NotificationPreference.allCases) { preference in
                    Text(preference.rawValue).tag(preference)
                }
            }
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
        .onChange(of: interlude.notificationPreference) { _, preference in
            if preference != .off {
                InterludeNotifications.requestAccess()
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

            Text("Icon")
                .font(.subheadline)
                .foregroundStyle(DaylightTheme.detailColor(interlude.tint, for: colorScheme))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(InterludeSymbol.options, id: \.self) { symbol in
                        Button {
                            interlude.symbolName = symbol
                        } label: {
                            Image(systemName: symbol)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(interlude.symbolName == symbol ? .white : DaylightTheme.titleColor(for: colorScheme))
                                .frame(width: 36, height: 36)
                                .background(
                                    interlude.symbolName == symbol ? interlude.tint : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(interlude.tint, lineWidth: interlude.symbolName == symbol ? 0 : 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(symbol)
                        .accessibilityAddTraits(interlude.symbolName == symbol ? .isSelected : [])
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
