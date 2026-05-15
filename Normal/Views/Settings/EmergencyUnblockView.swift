import SwiftData
import SwiftUI

struct EmergencyUnblockView: View {
    let settings: Settings
    @Binding var showConfirmation: Bool
    let performEmergencyUnblock: () -> Void

    @State private var showExplanation = false

    var body: some View {
        List {
            Section {
                Text("\(settings.emergencyUnblocksAvailable) of \(Settings.maxEmergencyUnblocks) remaining")
                Button("Emergency Unblock") { showConfirmation = true }
                    .disabled(settings.emergencyUnblocksAvailable == 0)
            } header: {
                Text("Emergency Unblock")
            } footer: {
                Text("Removes all blocks immediately without a key. Each use regenerates after 6 months.")
            }

            Section {
                ExpandableSection(
                    title: "How Emergency Unblocks Work",
                    isExpanded: $showExplanation
                ) {
                    explanationBody
                }
            }
        }
    }

    private var explanationBody: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text("Emergency unblocks provide a way to immediately remove all blocks when you need access urgently.")
                .font(.body)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("How it works:")
                    .font(.subheadline.weight(.semibold))
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    BulletRow(text: "Each emergency unblock regenerates after exactly 6 months")
                    BulletRow(text: "You get \(Settings.maxEmergencyUnblocks) uses total that replenish over time")
                    BulletRow(text: "All blocks are removed immediately when used")
                    BulletRow(text: "You can re-block apps afterward, but the emergency unblock takes 6 months to regenerate")
                    BulletRow(text: "Normal is fully offline, so we can't give you more emergency unblocks or reset them")
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DS.Spacing.sm)
    }
}
