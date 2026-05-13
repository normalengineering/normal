import FamilyControls
import SwiftData
import SwiftUI

struct ScheduleFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ScheduleService.self) private var scheduleService
    @Environment(ScreenTimeService.self) private var screenTimeService

    @Query private var allSchedules: [BlockSchedule]

    let existing: BlockSchedule?

    @State private var name: String
    @State private var selection: FamilyActivitySelection
    @State private var startTime: Date
    @State private var durationMinutes: Int
    @State private var selectedWeekdays: Set<Int>
    @State private var shouldBlock: Bool
    @State private var isTimed: Bool
    @State private var isShowingAppSelect = false
    @State private var error: Error?

    private var isNew: Bool { existing == nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && selectionCount(selection: selection) > 0
            && !selectedWeekdays.isEmpty
    }

    private static let durationOptions: [(Int, String)] = [
        (15, "15 min"),
        (30, "30 min"),
        (60, "1 hour"),
        (90, "1h 30m"),
        (120, "2 hours"),
        (180, "3 hours"),
        (240, "4 hours"),
        (480, "8 hours"),
        (720, "12 hours"),
    ]

    init(existing: BlockSchedule? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _selection = State(initialValue: existing?.selection ?? FamilyActivitySelection())
        _durationMinutes = State(initialValue: existing?.durationMinutes ?? 60)
        _selectedWeekdays = State(initialValue: existing?.weekdays ?? Set(2 ... 6))
        _shouldBlock = State(initialValue: existing?.shouldBlock ?? true)
        _isTimed = State(initialValue: existing?.isTimed ?? true)

        if let existing {
            var components = DateComponents()
            components.hour = existing.startHour
            components.minute = existing.startMinute
            _startTime = State(
                initialValue: Calendar.current.date(from: components) ?? .now
            )
        } else {
            var components = DateComponents()
            components.hour = 9
            components.minute = 0
            _startTime = State(
                initialValue: Calendar.current.date(from: components) ?? .now
            )
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                appSection
                modeSection
                timingSection
                timeSection
                weekdaySection
                errorSection
            }
            .navigationTitle(isNew ? "New Schedule" : "Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Save" : "Update") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isShowingAppSelect) {
                SelectAppsForGroupSheet(selection: $selection)
            }
        }
    }

    private var nameSection: some View {
        Section("Name") {
            TextField("e.g. Work Hours", text: $name)
        }
    }

    private var appSection: some View {
        Section("Apps") {
            Button {
                Task {
                    guard await screenTimeService.ensureAuthorized() else { return }
                    isShowingAppSelect = true
                }
            } label: {
                HStack {
                    Text("Select Apps")
                        .foregroundStyle(.primary)
                    Spacer()
                    let count = selectionCount(selection: selection)
                    if count > 0 {
                        Text("\(count)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var modeSection: some View {
        Section {
            Picker("Mode", selection: $shouldBlock) {
                Label("Block", systemImage: "lock.fill").tag(true)
                Label("Unblock", systemImage: "lock.open.fill").tag(false)
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Action")
        } footer: {
            Text(
                shouldBlock
                    ? "Selected apps will be blocked when the schedule activates."
                    : "Selected apps will be unblocked when the schedule activates."
            )
        }
    }

    private var timingSection: some View {
        Section {
            Picker("Timing", selection: $isTimed) {
                Text("Timed").tag(true)
                Text("Permanent").tag(false)
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Duration Type")
        } footer: {
            Text(
                isTimed
                    ? "The action will automatically reverse after the duration ends."
                    : "The action will persist until you manually change it."
            )
        }
    }

    private var timeSection: some View {
        Section("Time") {
            DatePicker(
                "Starts at",
                selection: $startTime,
                displayedComponents: .hourAndMinute
            )

            if isTimed {
                Picker("Duration", selection: $durationMinutes) {
                    ForEach(Self.durationOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
            }
        }
    }

    private var weekdaySection: some View {
        Section("Repeat") {
            WeekdayPickerView(selected: $selectedWeekdays)
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error {
            Section {
                MessageView(message: error.localizedDescription, color: .red)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let components = Calendar.current.dateComponents(
            [.hour, .minute], from: startTime
        )

        let schedule: BlockSchedule
        if let existing {
            existing.name = trimmed
            existing.selection = selection
            existing.startHour = components.hour ?? 0
            existing.startMinute = components.minute ?? 0
            existing.durationMinutes = durationMinutes
            existing.weekdays = selectedWeekdays
            existing.shouldBlock = shouldBlock
            existing.isTimed = isTimed
            schedule = existing
        } else {
            schedule = BlockSchedule(
                name: trimmed,
                selection: selection,
                startHour: components.hour ?? 0,
                startMinute: components.minute ?? 0,
                durationMinutes: durationMinutes,
                weekdays: selectedWeekdays,
                shouldBlock: shouldBlock,
                isTimed: isTimed
            )
            modelContext.insert(schedule)
        }

        do {
            try scheduleService.syncAndPersist(
                schedule,
                allSchedules: allSchedules + (isNew ? [schedule] : []),
                screenTimeService: screenTimeService
            )
            dismiss()
        } catch {
            self.error = error
        }
    }
}
