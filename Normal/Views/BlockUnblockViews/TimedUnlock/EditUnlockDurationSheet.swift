import SwiftData
import SwiftUI

struct EditUnlockGrant: Identifiable {
    let id = UUID()
    let proof: KeyProof

    init?(proof: KeyProof) {
        guard proof.coversAllApps else { return nil }
        self.proof = proof
    }
}

struct EditUnlockDurationSheet: View {
    @Environment(EditSessionService.self) private var editSessionService
    @Query private var allSettings: [Settings]

    let grant: EditUnlockGrant

    private var settings: Settings {
        allSettings.unwrapped
    }

    var body: some View {
        TimedUnblockSheet(
            title: String(localized: "Unblock Editing"),
            durations: settings.unblockDurations,
            initialDuration: settings.resolvedEditDefaultDuration,
            timedFooter: "Editing will automatically re-block after this time.",
            permanentFooter: "You will need to manually block editing again.",
            onConfirm: { length in
                editSessionService.unblock(for: length, proof: grant.proof)
            }
        )
    }
}
