import SwiftUI

struct TimedUnblockSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let durations: [TimedUnblockDuration]
    let timedHeader: LocalizedStringKey
    let timedFooter: LocalizedStringKey
    let permanentTitle: LocalizedStringKey
    let permanentFooter: LocalizedStringKey
    let onConfirm: (UnblockLength) throws -> Void

    @State private var selection: UnblockLength
    @State private var error: Error?

    init(
        title: String,
        durations: [TimedUnblockDuration],
        initialDuration: TimedUnblockDuration?,
        timedHeader: LocalizedStringKey = "Timed Unblock",
        timedFooter: LocalizedStringKey = "Apps will automatically re-block after this time, even if you close the app.",
        permanentTitle: LocalizedStringKey = "Until Manually Re-Blocked",
        permanentFooter: LocalizedStringKey = "You will need to manually block apps again.",
        onConfirm: @escaping (UnblockLength) throws -> Void
    ) {
        self.title = title
        self.durations = durations
        self.timedHeader = timedHeader
        self.timedFooter = timedFooter
        self.permanentTitle = permanentTitle
        self.permanentFooter = permanentFooter
        self.onConfirm = onConfirm
        _selection = State(initialValue: (initialDuration ?? durations.first).map(UnblockLength.timed) ?? .permanent)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(durations) { duration in
                        ChoiceListRow(
                            title: LocalizedStringKey(duration.label),
                            isSelected: selection == .timed(duration)
                        ) {
                            selection = .timed(duration)
                        }
                        .accessibilityIdentifier("timedUnblock.duration.\(duration.seconds)")
                    }
                } header: {
                    Text(timedHeader)
                } footer: {
                    Text(timedFooter)
                }

                Section {
                    ChoiceListRow(
                        title: permanentTitle,
                        isSelected: selection == .permanent
                    ) {
                        selection = .permanent
                    }
                    .accessibilityIdentifier("timedUnblock.permanent")
                } footer: {
                    Text(permanentFooter)
                }

                if let error {
                    Section {
                        MessageView(message: error.localizedDescription, color: .red)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm", action: performUnblock)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("timedUnblock.confirm")
                }
            }
        }
    }

    private func performUnblock() {
        do {
            try onConfirm(selection)
            dismiss()
        } catch {
            self.error = error
        }
    }
}
