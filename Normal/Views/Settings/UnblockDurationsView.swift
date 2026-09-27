import SwiftUI

struct UnblockDurationsView: View {
    let settings: Settings

    @State private var isAdding = false
    @State private var pendingDefaultDeletion: TimedUnblockDuration?
    @State private var showLastDurationAlert = false

    private var durations: [TimedUnblockDuration] { settings.unblockDurations }
    private var isAtLimit: Bool { durations.count >= Settings.maxUnblockDurations }

    var body: some View {
        List {
            Section {
                ForEach(durations) { duration in
                    row(duration)
                }
                .onDelete { offsets in
                    offsets.map { durations[$0] }.first.map(attemptDelete)
                }
            } footer: {
                Text(isAtLimit
                    ? "You can save up to \(Settings.maxUnblockDurations) durations."
                    : "Durations you can pick when unblocking. Minimum 15 minutes.")
            }
        }
        .navigationTitle("Unblock Durations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAdding = true } label: {
                    Label("Add Duration", systemImage: "plus")
                }
                .disabled(isAtLimit)
                .accessibilityIdentifier("unblockDurations.addButton")
            }
        }
        .sheet(isPresented: $isAdding) {
            AddUnblockDurationSheet(existing: durations) { settings.addUnblockDuration($0) }
        }
        .alert(
            "Delete Default Duration?",
            isPresented: Binding(
                get: { pendingDefaultDeletion != nil },
                set: { if !$0 { pendingDefaultDeletion = nil } }
            ),
            presenting: pendingDefaultDeletion
        ) { duration in
            Button("Delete", role: .destructive) { remove(duration) }
            Button("Cancel", role: .cancel) {}
        } message: { duration in
            Text("\(duration.label) is your default duration. Deleting it sets Default Duration to None. You can choose a new default anytime.")
        }
        .alert("Can't Delete Duration", isPresented: $showLastDurationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("At least one unblock duration must exist. Add another duration before deleting this one.")
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: durations)
    }

    private func row(_ duration: TimedUnblockDuration) -> some View {
        let isDefault = settings.isDefault(duration)
        return HStack(spacing: DS.Spacing.md) {
            Image(systemName: "timer")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: DS.Spacing.xs - 2) {
                Text(duration.label)
                if isDefault {
                    Text("Default")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("unblockDurations.row.\(duration.seconds)")
        .swipeActions(edge: .leading) {
            defaultToggleButton(duration, isDefault: isDefault)
                .tint(.accentColor)
        }
        .contextMenu {
            defaultToggleButton(duration, isDefault: isDefault)
            Button(role: .destructive) { attemptDelete(duration) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func defaultToggleButton(_ duration: TimedUnblockDuration, isDefault: Bool) -> some View {
        Button {
            settings.defaultDuration = isDefault ? nil : duration
        } label: {
            if isDefault {
                Label("Remove Default", systemImage: "star.slash")
            } else {
                Label("Set as Default", systemImage: "star")
            }
        }
    }

    private func attemptDelete(_ duration: TimedUnblockDuration) {
        if durations.count <= 1 {
            showLastDurationAlert = true
        } else if settings.isDefault(duration) {
            pendingDefaultDeletion = duration
        } else {
            remove(duration)
        }
    }

    private func remove(_ duration: TimedUnblockDuration) {
        withAnimation { _ = settings.removeUnblockDuration(duration) }
    }
}

struct AddUnblockDurationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existing: [TimedUnblockDuration]
    let onAdd: (TimedUnblockDuration) -> Void

    @State private var hours = 0
    @State private var minutes = 30

    private static let minuteOptions = Array(stride(from: 0, to: 60, by: TimedUnblockDuration.stepSeconds / 60))
    private static let liveActivityLimitHours = 8

    private var duration: TimedUnblockDuration? {
        TimedUnblockDuration(hours: hours, minutes: minutes)
    }

    private var isDuplicate: Bool {
        duration.map(existing.contains) ?? false
    }

    private var canAdd: Bool { duration != nil && !isDuplicate }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 0) {
                        wheel("Hours", unit: "hr", selection: $hours, options: Array(0 ..< 24))
                            .accessibilityIdentifier("durationPicker.hours")
                        wheel("Minutes", unit: "min", selection: $minutes, options: Self.minuteOptions)
                            .accessibilityIdentifier("durationPicker.minutes")
                    }
                } header: {
                    if let duration {
                        Text(duration.label)
                    }
                } footer: {
                    footer
                }
            }
            .navigationTitle("Add Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                        .fontWeight(.semibold)
                        .disabled(!canAdd)
                        .accessibilityIdentifier("durationPicker.addButton")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var footer: some View {
        if duration == nil {
            Text("Duration must be at least \(TimedUnblockDuration.minimumSeconds / 60) minutes.")
                .foregroundStyle(.red)
        } else if isDuplicate {
            Text("This duration is already in your list.")
                .foregroundStyle(.red)
        } else if hours >= Self.liveActivityLimitHours {
            Text("Live Activity countdowns end after \(Self.liveActivityLimitHours) hours. Apps still re-block on time.")
        }
    }

    private func wheel(
        _ title: LocalizedStringKey,
        unit: LocalizedStringKey,
        selection: Binding<Int>,
        options: [Int]
    ) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { value in
                    Text(verbatim: "\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .accessibilityLabel(title)
            Text(unit)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }

    private func add() {
        guard let duration, canAdd else { return }
        onAdd(duration)
        dismiss()
    }
}
