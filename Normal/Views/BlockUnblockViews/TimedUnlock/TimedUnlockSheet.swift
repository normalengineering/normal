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
                        Button {
                            selectedDuration = duration
                        } label: {
                            HStack {
                                Text(duration.label)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedDuration == duration {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Timed Unblock")
                } footer: {
                    Text("Apps will automatically re-block after this time, even if you close the app.")
                }

                Section {
                    Button {
                        selectedDuration = nil
                    } label: {
                        HStack {
                            Text("Until Manually Re-Blocked")
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedDuration == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                                    .fontWeight(.semibold)
                            }
                        }
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
                    Button("Confirm") { performUnblock() }
                        .fontWeight(.semibold)
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
