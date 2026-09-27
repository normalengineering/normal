import SwiftUI

struct TimedUnblockSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let durations: [TimedUnblockDuration]
    let onTimedUnblock: (TimedUnblockDuration) throws -> Void
    let onPermanentUnblock: () -> Void

    @State private var selectedDuration: TimedUnblockDuration?
    @State private var error: Error?

    init(
        title: String,
        durations: [TimedUnblockDuration],
        initialDuration: TimedUnblockDuration?,
        onTimedUnblock: @escaping (TimedUnblockDuration) throws -> Void,
        onPermanentUnblock: @escaping () -> Void
    ) {
        self.title = title
        self.durations = durations
        self.onTimedUnblock = onTimedUnblock
        self.onPermanentUnblock = onPermanentUnblock
        _selectedDuration = State(initialValue: initialDuration ?? durations.first)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(durations) { duration in
                        ChoiceListRow(
                            title: LocalizedStringKey(duration.label),
                            isSelected: selectedDuration == duration
                        ) {
                            selectedDuration = duration
                        }
                        .accessibilityIdentifier("timedUnblock.duration.\(duration.seconds)")
                    }
                } header: {
                    Text("Timed Unblock")
                } footer: {
                    Text("Apps will automatically re-block after this time, even if you close the app.")
                }

                Section {
                    ChoiceListRow(
                        title: "Until Manually Re-Blocked",
                        isSelected: selectedDuration == nil
                    ) {
                        selectedDuration = nil
                    }
                    .accessibilityIdentifier("timedUnblock.permanent")
                } footer: {
                    Text("You will need to manually block apps again.")
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
        if let duration = selectedDuration {
            do {
                try onTimedUnblock(duration)
                dismiss()
            } catch {
                self.error = error
            }
        } else {
            onPermanentUnblock()
            dismiss()
        }
    }
}
