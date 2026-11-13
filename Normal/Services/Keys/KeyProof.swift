import Foundation

struct KeyProof: Equatable {
    let keyGroupID: UUID?

    var coversAllApps: Bool {
        keyGroupID == nil
    }

    func covers(_ target: UnblockTarget) -> Bool {
        coversAllApps || keyGroupID == target.groupID
    }
}

struct UnblockGrant: Identifiable {
    let target: UnblockTarget

    init?(_ target: UnblockTarget, proof: KeyProof) {
        guard proof.covers(target) else { return nil }
        self.target = target
    }

    var id: String {
        target.id
    }
}
