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
    @State private var endTime: Date
    @State private var selectedWeekdays: Set<Int>
    @State private var shouldBlock: Bool
    @State private var isTimed: Bool
    @State private var isShowingAppSelect = false
    @State private var error: Error?

    private var isNew: Bool { existing == nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && selection.count > 0
            && !selectedWeekdays.isEmpty
            && (!isTimed || computedDurationMinutes > 0)
    }

    private var computedDurationMinutes: Int {
        let startComps = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        let endComps = Calendar.current.dateComponents([.hour, .minute], from: endTime)
        let startMin = (startComps.hour ?? 0) * 60 + (startComps.minute ?? 0)
        let endMin = (endComps.hour ?? 0) * 60 + (endComps.minute ?? 0)
        let diff = endMin - startMin
        return diff > 0 ? diff : diff + (24 * 60)
    }

    init(existing: BlockSchedule? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _selection = State(initialValue: existing?.selection ?? FamilyActivitySelection())
        _selectedWeekdays = State(initialValue: existing?.weekdays ?? Set(2 ... 6))
        _shouldBlock = State(initialValue: existing?.shouldBlock ?? false)
        _isTimed = State(initialValue: existing?.isTimed ?? true)

        var startComponents = DateComponents()
        startComponents.hour = existing?.startHour ?? 9
        startComponents.minute = existing?.startMinute ?? 0
        let start = Calendar.current.date(from: startComponents) ?? .now
        _startTime = State(initialValue: start)

        let initialDuration = existing?.durationMinutes ?? 60
        let end = Calendar.current.date(byAdding: .minute, value: initialDuration, to: start) ?? start
        _endTime = State(initialValue: end)
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
                    Button(isNew ? "Save" : "Update", action: save)
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
            Button(action: presentPicker) {
                CountChevronRow(title: "Select Apps", count: selection.count)
            }
        }
    }

    private var modeSection: some View {
        Section {
            Picker("Mode", selection: $shouldBlock) {
                Label("Unblock", systemImage: "lock.open.fill").tag(false)
                Label("Block", systemImage: "lock.fill").tag(true)
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
        Section {
            DatePicker("Starts at", selection: $startTime, displayedComponents: .hourAndMinute)
            if isTimed {
                DatePicker("Ends at", selection: $endTime, displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Time")
        } footer: {
            if isTimed {
                Text("Duration: \(formattedComputedDuration)")
            }
        }
    }

    private var formattedComputedDuration: String {
        let total = computedDurationMinutes
        let hours = total / 60
        let minutes = total % 60
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
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

    private func presentPicker() {
        screenTimeService.ifAuthorized { isShowingAppSelect = true }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let components = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        let durationMinutes = computedDurationMinutes

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
            let nextIndex = SortIndexing.nextIndex(after: allSchedules, sortIndex: \.sortIndex)
            schedule = BlockSchedule(
                name: trimmed,
                selection: selection,
                startHour: components.hour ?? 0,
                startMinute: components.minute ?? 0,
                durationMinutes: durationMinutes,
                weekdays: selectedWeekdays,
                shouldBlock: shouldBlock,
                isTimed: isTimed,
                isEnabled: false,
                sortIndex: nextIndex
            )
            modelContext.insert(schedule)
        }

        do {
            if isNew {
                scheduleService.syncAllToSharedStore(allSchedules + [schedule])
            } else {
                try scheduleService.syncAndPersist(
                    schedule,
                    allSchedules: allSchedules,
                    screenTimeService: screenTimeService
                )
            }
            dismiss()
        } catch {
            self.error = error
        }
    }
}
