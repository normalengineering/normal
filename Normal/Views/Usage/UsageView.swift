import SwiftData
import SwiftUI

/// Daily usage limits. Each one covers a set of apps that share its allowance,
/// the way Screen Time's own App Limits work.
struct UsageView: View {
    @Environment(UsageLimitService.self) private var usageLimitService

    @Query(sort: [SortDescriptor(\UsageLimit.sortIndex)]) private var limits: [UsageLimit]

    @State private var editing: UsageLimitTarget?

    var body: some View {
        List {
            limitsSection
            if !limits.isEmpty { resetSection }
        }
        .navigationTitle("Usage")
        .navigationBarTitleDisplayMode(.inline)
        // Pinned rather than a section footer: the rule applies to the whole
        // screen, including the empty state before any limit exists.
        .safeAreaInset(edge: .bottom) {
            FooterMessage(text: UsageLimitMessage.weeklyChange)
        }
        .sheet(item: $editing) { target in
            NavigationStack {
                UsageLimitEditor(target: target) { editing = nil }
            }
        }
    }

    private var limitsSection: some View {
        Section {
            ForEach(limits) { row(for: $0) }
            Button { editing = .new } label: {
                Label("Add Limit", systemImage: "plus")
            }
            .accessibilityIdentifier("usage.addLimit")
        } header: {
            Text("App Limits")
        } footer: {
            Text("Caps how long you can use the chosen apps each day. Once a limit runs out those apps lock again for the rest of the day, even while everything else is unblocked.")
        }
    }

    private var resetSection: some View {
        Section {
            LabeledContent("Resets") {
                Text(usageLimitService.nextReset(), style: .time)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text("Unused time does not carry over.")
        }
    }

    private func row(for limit: UsageLimit) -> some View {
        Button { editing = .existing(limit) } label: {
            HStack(spacing: DS.Spacing.sm) {
                UsageLimitRow(limit: limit, state: usageLimitService.state(for: limit))
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
