import Foundation

enum ProtectedAction {
    case tighten(@MainActor () -> Void)
    case weaken(@MainActor (KeyProof) -> Void)

    var allowsBypass: Bool {
        if case .tighten = self {
            return true
        }
        return false
    }

    func run(with proof: KeyProof?) {
        switch self {
        case .tighten(let action):
            action()
        case .weaken(let action):
            if let proof {
                action(proof)
            }
        }
    }
}
