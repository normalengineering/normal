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
        case let .tighten(action):
            action()
        case let .weaken(action):
            if let proof {
                action(proof)
            }
        }
    }
}
