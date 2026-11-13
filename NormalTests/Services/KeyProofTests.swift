import FamilyControls
import Foundation
@testable import Normal
import Testing

@MainActor
struct KeyProofTests {
    private let main = SelectedApps(selection: FamilyActivitySelection())
    private let social = AppGroup(name: "Social", selection: FamilyActivitySelection())
    private let work = AppGroup(name: "Work", selection: FamilyActivitySelection())

    private final class Counter {
        var runs = 0
    }

    @Test func globalKeyCoversEverything() {
        let proof = KeyProof(keyGroupID: nil)
        #expect(proof.coversAllApps)
        #expect(proof.covers(.all(main)))
        #expect(proof.covers(.group(social)))
    }

    @Test func groupKeyCoversOnlyItsGroup() {
        let proof = KeyProof(keyGroupID: social.id)
        #expect(!proof.coversAllApps)
        #expect(!proof.covers(.all(main)))
        #expect(proof.covers(.group(social)))
        #expect(!proof.covers(.group(work)))
    }

    @Test func grantNeedsAProofThatCoversItsTarget() {
        let proof = KeyProof(keyGroupID: social.id)
        #expect(UnblockGrant(.group(social), proof: proof)?.target.groupID == social.id)
        #expect(UnblockGrant(.all(main), proof: proof) == nil)
        #expect(UnblockGrant(.group(work), proof: proof) == nil)
    }

    @Test func onlyTighteningAllowsBypass() {
        #expect(ProtectedAction.tighten {}.allowsBypass)
        #expect(!ProtectedAction.weaken { _ in }.allowsBypass)
    }

    @Test func weakeningRunsOnlyWithAProof() {
        let counter = Counter()
        let action = ProtectedAction.weaken { _ in counter.runs += 1 }

        action.run(with: nil)
        #expect(counter.runs == 0)

        action.run(with: KeyProof(keyGroupID: nil))
        #expect(counter.runs == 1)
    }

    @Test func tighteningRunsWithoutAProof() {
        let counter = Counter()
        ProtectedAction.tighten { counter.runs += 1 }.run(with: nil)
        #expect(counter.runs == 1)
    }
}
