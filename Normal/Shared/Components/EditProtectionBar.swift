import SwiftData
import SwiftUI
import UIKit

struct EditProtectionBarModifier<Fallback: View>: ViewModifier {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(EditSessionService.self) private var editSessionService
    @Query private var allSettings: [Settings]
    @Query private var keys: [Key]

    let unblockAllMessage: LocalizedStringKey
    let blockedLabel: LocalizedStringKey
    let allowWhenNoKeys: Bool
    let showsBlockedBar: Bool
    let fallback: Fallback

    @State private var authAction: ProtectedAction?
    @State private var durationGrant: EditUnlockGrant?

    private var settings: Settings {
        allSettings.unwrapped
    }

    private var mode: EditProtectionMode {
        settings.editProtectionMode
    }

    private var isBlocked: Bool {
        editSessionService.isEditingBlocked(
            mode: mode,
            keys: keys,
            activeShieldCount: screenTimeService.activeShieldCount(),
            allowWhenNoKeys: allowWhenNoKeys
        )
    }

    private var hasUsableGlobalKey: Bool {
        EditSessionService.hasUsableGlobalKey(in: keys)
    }

    private var showsActiveSession: Bool {
        mode == .requireKey && editSessionService.isActive && hasUsableGlobalKey
    }

    func body(content: Content) -> some View {
        content
            .bottomFooter {
                footerContent
            }
            .background {
                Color.clear
                    .keySelect(
                        action: $authAction,
                        defaultKeyType: settings.resolvedEditDefaultKeyType
                    )
            }
            .background {
                Color.clear
                    .sheet(item: $durationGrant) { grant in
                        EditUnlockDurationSheet(grant: grant)
                    }
            }
    }

    @ViewBuilder
    private var footerContent: some View {
        if showsActiveSession {
            activeSessionBar
        } else if showsBlockedBar, isBlocked {
            if mode == .requireKey && hasUsableGlobalKey {
                blockedKeyBar
            } else {
                FooterMessage(text: unblockAllMessage)
            }
        } else {
            fallback
        }
    }

    private var blockedKeyBar: some View {
        AdaptiveStack(spacing: DS.Spacing.md) {
            Label(blockedLabel, systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("editProtection.blockedLabel")

            Button("Unblock Editing", action: requestUnblock)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityIdentifier("editProtection.unblockButton")
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    private var activeSessionBar: some View {
        AdaptiveStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: editSessionService.isPermanent ? "lock.open.fill" : "timer")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: DS.Spacing.xs - 2) {
                    Text("Editing Unblocked")
                        .font(.footnote.weight(.semibold))
                    if editSessionService.isPermanent {
                        Text("Until manually re-blocked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let endDate = editSessionService.endDate {
                        Text(timerInterval: .now...max(.now, endDate), countsDown: true)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("editProtection.activeLabel")

            Button("Block Now", action: blockEditing)
                .buttonStyle(.bordered)
                .tint(.orange)
                .controlSize(.small)
                .accessibilityIdentifier("editProtection.blockButton")
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    private func requestUnblock() {
        authAction = .weaken { proof in
            completeUnblock(proof)
        }
    }

    private func completeUnblock(_ proof: KeyProof) {
        guard let grant = EditUnlockGrant(proof: proof) else { return }
        if let duration = settings.resolvedEditDefaultDuration {
            editSessionService.unblock(for: .timed(duration), proof: proof)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            durationGrant = grant
        }
    }

    private func blockEditing() {
        editSessionService.block()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

extension View {
    func editProtectionBar(
        unblockAllMessage: LocalizedStringKey,
        blockedLabel: LocalizedStringKey = "Editing is blocked.",
        allowWhenNoKeys: Bool = false
    ) -> some View {
        modifier(
            EditProtectionBarModifier(
                unblockAllMessage: unblockAllMessage,
                blockedLabel: blockedLabel,
                allowWhenNoKeys: allowWhenNoKeys,
                showsBlockedBar: true,
                fallback: EmptyView()
            ))
    }

    func editProtectionBar<Fallback: View>(
        unblockAllMessage: LocalizedStringKey,
        blockedLabel: LocalizedStringKey = "Editing is blocked.",
        allowWhenNoKeys: Bool = false,
        @ViewBuilder fallback: () -> Fallback
    ) -> some View {
        modifier(
            EditProtectionBarModifier(
                unblockAllMessage: unblockAllMessage,
                blockedLabel: blockedLabel,
                allowWhenNoKeys: allowWhenNoKeys,
                showsBlockedBar: true,
                fallback: fallback()
            ))
    }

    func activeEditSessionBar() -> some View {
        modifier(
            EditProtectionBarModifier(
                unblockAllMessage: "",
                blockedLabel: "Editing is blocked.",
                allowWhenNoKeys: false,
                showsBlockedBar: false,
                fallback: EmptyView()
            ))
    }
}
