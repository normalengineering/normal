import SwiftData
import SwiftUI

struct ScheduleCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ScheduleService.self) private var scheduleService
    @Environment(ScreenTimeService.self) private var screenTimeService

    @Query private var allSchedules: [BlockSchedule]
    @Query private var keys: [Key]

    let schedule: BlockSchedule

    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @State private var error: Error?

    private var isBlocked: Bool {
        screenTimeService.activeShieldCount() > 0
    }

    private var hasKeys: Bool {
        !keys.isEmpty
    }

    private var isLocked: Bool {
        isBlocked || !hasKeys
    }

    var body: some View {
        CardView {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(schedule.name)
                        .font(.headline)

                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Image(systemName: schedule.shouldBlock ? "lock.fill" : "lock.open.fill")
                                .font(.caption2)
                            Text(schedule.shouldBlock ? "Block" : "Unblock")
                                .font(.caption)
                        }
                        .foregroundStyle(schedule.shouldBlock ? .red : .green)

                        Text("·")
                            .foregroundStyle(.secondary)

                        HStack(spacing: 3) {
                            Image(systemName: schedule.isTimed ? "hourglass" : "infinity")
                                .font(.caption2)
                            Text(schedule.isTimed ? "Timed" : "Permanent")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Toggle("", isOn: enabledBinding)
                    .labelsHidden()
                    .tint(.accentColor)
                    .disabled(isLocked)
            }

            HStack(spacing: 16) {
                if schedule.isTimed {
                    Label(
                        "\(schedule.formattedStartTime) – \(schedule.formattedEndTime)",
                        systemImage: "clock"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Label(schedule.formattedDuration, systemImage: "hourglass")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Starts \(schedule.formattedStartTime)", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 4) {
                ForEach(schedule.weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if !allTokensFromSelection(selection: schedule.selection).isEmpty {
                HStack(spacing: 8) {
                    SelectionIconsView(
                        tokens: allTokensFromSelection(selection: schedule.selection)
                    )
                }
            }
        }
        .opacity(schedule.isEnabled && !isLocked ? 1.0 : 0.6)
        .onTapGesture { if !isLocked { isEditing = true } }
        .contextMenu { contextActions }
        .sheet(isPresented: $isEditing) {
            ScheduleFormSheet(existing: schedule)
        }
        .alert("Delete Schedule?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) { deleteSchedule() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(schedule.name) will be permanently removed.")
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { schedule.isEnabled },
            set: { _ in toggleEnabled() }
        )
    }

    private func toggleEnabled() {
        do {
            try scheduleService.toggleEnabled(
                schedule,
                screenTimeService: screenTimeService
            )
            scheduleService.syncAllToSharedStore(allSchedules)
        } catch {
            self.error = error
        }
    }

    private func deleteSchedule() {
        scheduleService.remove(schedule, screenTimeService: screenTimeService)
        modelContext.delete(schedule)
        let remaining = allSchedules.filter { $0.id != schedule.id }
        scheduleService.syncAllToSharedStore(remaining)
    }

    @ViewBuilder
    private var contextActions: some View {
        Button {
            isEditing = true
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        .disabled(isLocked)

        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .disabled(isLocked)
    }
}
