import SwiftUI

struct NewInterludeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var onAdd: (SavedInterlude) -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose suggested interludes or create your own.")
                        .font(.headline)
                        .foregroundStyle(DaylightTheme.titleColor(for: colorScheme))

                    ForEach(InterludeLibrary.suggestions) { template in
                        Button {
                            add(template.makeInterlude())
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
                        add(customInterlude)
                    } label: {
                        SuggestionCard(
                            name: "Custom interlude",
                            detail: "Flip the card to configure it",
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
    }

    private var customInterlude: SavedInterlude {
        SavedInterlude(
            name: "Custom interlude",
            symbolName: "slider.horizontal.3",
            tint: DaylightTheme.pine,
            tintName: "pine",
            type: .interval,
            repeatMinutes: 25
        )
    }

    private func add(_ interlude: SavedInterlude) {
        onAdd(interlude)
        dismiss()
    }
}

#Preview("Add") {
    NavigationStack {
        NewInterludeView { _ in }
    }
}
