import SwiftUI

struct TimedUnblockSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onTimedUnblock: (UnblockDuration) throws -> Void
    let onPermanentUnblock: () -> Void

    @State private var selectedDuration: UnblockDuration? = .fifteenMinutes
    @State private var error: Error?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(UnblockDuration.allCases) { duration in
                        ChoiceListRow(
                            title: LocalizedStringKey(duration.label),
                            isSelected: selectedDuration == duration
                        ) {
                            selectedDuration = duration
                        }
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
                    Button("Confirm", action: performUnblock).fontWeight(.semibold)
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
