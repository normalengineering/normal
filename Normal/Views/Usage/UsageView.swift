import SwiftData
import SwiftUI

struct UsageView: View {
    @Environment(UsageLimitService.self) private var usageLimitService

    @Query(sort: [SortDescriptor(\UsageLimit.sortIndex)]) private var limits: [UsageLimit]
    @Query private var allSettings: [Settings]

    @State private var editing: UsageLimitTarget?

    private var settings: Settings {
        allSettings.unwrapped
    }

    var body: some View {
        TimelineView(UsageLockSchedule(dates: limits.flatMap(\.lockRefreshDates))) { context in
            List {
                noticeSection
                if limits.isEmpty {
                    UsageLimitsGuideView { editing = .new }
                } else {
                    limitsSection(now: context.date)
                }
                resetSection
            }
        }
        .navigationTitle("Max Daily Limits")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editing = .new } label: {
                    Label("Add Limit", systemImage: "plus")
                }
                .accessibilityIdentifier("usage.addLimit")
            }
        }
        .sheet(item: $editing) { UsageLimitEditor(target: $0) }
    }

    @ViewBuilder
    private var noticeSection: some View {
        if !limits.isEmpty, usageLimitService.isDayOverridden() {
            let reset = usageLimitService.nextReset().formatted(date: .omitted, time: .shortened)
            Section {
                MessageView(text: Text("Paused by emergency unblock until \(reset)."), color: .orange)
                    .standaloneListRow()
                    .accessibilityIdentifier("usage.notice")
            }
        }
    }

    private func limitsSection(now: Date) -> some View {
        let states = usageLimitService.states(for: limits)
        return Section {
            ForEach(limits) { limit in
                Button { editing = .existing(limit) } label: {
                    UsageLimitRow(limit: limit, state: states[limit.id] ?? .under, now: now)
                }
                .tint(.primary)
                .accessibilityHint("Edit limit")
            }
        } footer: {
            Text("Once a limit runs out, its apps stay blocked until the reset, even while everything else is unblocked.")
        }
    }

    private var resetSection: some View {
        Section {
            NavigationLink {
                UsageResetTimeView(currentMinutes: settings.dailyLimitResetMinutes)
            } label: {
                LabeledContent("Resets At") {
                    Text(usageLimitService.nextReset(), style: .time)
                }
            }
            .accessibilityIdentifier("usage.resetTime")
        } footer: {
            Text("Unused time does not carry over.")
        }
    }
}

struct UsageResetTimeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UsageLimitService.self) private var usageLimitService

    @Query private var limits: [UsageLimit]
    @Query private var allSettings: [Settings]

    @State private var time: Date

    init(currentMinutes: Int) {
        let time = Calendar.current.date(
            bySettingHour: currentMinutes / 60,
            minute: currentMinutes % 60,
            second: 0,
            of: .now
        )
        _time = State(initialValue: time ?? .now)
    }

    private var settings: Settings {
        allSettings.unwrapped
    }

    private var newMinutes: Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private var hasChange: Bool {
        newMinutes != settings.dailyLimitResetMinutes
    }

    private func decision(at now: Date) -> UsageLimitEditDecision {
        limits.isEmpty ? .allowed(.tightening) : usageLimitService.decideResetChange(now: now)
    }

    private func notice(at now: Date) -> Text? {
        guard !limits.isEmpty else { return nil }
        switch usageLimitService.resetLockState(now: now) {
        case .unlocked:
            return nil
        case let .grace(until):
            return Text("You can change the reset time for another \(UsageLockDeadline.countdown(to: until, now: now)).")
        case let .locked(until):
            return Text("You can change the reset time again \(UsageLockDeadline.phrase(until: until, now: now)).")
        }
    }

    var body: some View {
        TimelineView(UsageLockSchedule(dates: usageLimitService.resetLockRefreshDates())) { context in
            form(now: context.date)
        }
        .navigationTitle("Reset Time")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func form(now: Date) -> some View {
        Form {
            if let notice = notice(at: now) {
                Section {
                    MessageView(text: notice, color: .orange)
                        .standaloneListRow()
                        .accessibilityIdentifier("usage.resetNotice")
                }
            }

            Section {
                DatePicker("Resets At", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("usage.resetPicker")
            } footer: {
                Text("Every limit's time resets at this time each day. While you have limits, it can be changed once every 7 days, with 10 minutes to adjust after each change.")
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .fontWeight(.semibold)
                    .disabled(!hasChange || !decision(at: now).isAllowed)
                    .accessibilityIdentifier("usage.resetSave")
            }
        }
    }

    private func save() {
        guard case let .allowed(allowance) = decision(at: .now) else { return }
        usageLimitService.commitResetChange(allowance)
        settings.dailyLimitResetMinutes = newMinutes
        usageLimitService.registerAll(limits, config: settings.usageLimitConfig)
        dismiss()
    }
}
