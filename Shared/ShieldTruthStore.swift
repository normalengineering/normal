import FamilyControls
import Foundation
import ManagedSettings

nonisolated struct DesiredShield: Codable, Equatable {
    var applications: Set<ApplicationToken> = []
    var webDomains: Set<WebDomainToken> = []
    var categories: Set<ActivityCategoryToken> = []
    var denyAppRemoval = false

    static let empty = DesiredShield()
}

struct ShieldTruthStore {
    private let fileURL: URL
    private let coordinator = NSFileCoordinator()

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: SharedConstants.appGroupID
            )
            self.fileURL = (container ?? FileManager.default.temporaryDirectory)
                .appendingPathComponent("ShieldTruth.plist")
        }
    }

    func snapshot() -> DesiredShield {
        var result = DesiredShield.empty
        var coordinationError: NSError?
        coordinator.coordinate(readingItemAt: fileURL, options: [], error: &coordinationError) { url in
            result = decode(try? Data(contentsOf: url))
        }
        return result
    }

    func mutate(
        _ body: (inout DesiredShield) -> Void,
        reconcile: (_ old: DesiredShield, _ new: DesiredShield) -> Void
    ) {
        var coordinationError: NSError?
        coordinator.coordinate(writingItemAt: fileURL, options: [], error: &coordinationError) { url in
            let old = decode(try? Data(contentsOf: url))
            var updated = old
            body(&updated)

            if updated != old, let data = try? PropertyListEncoder().encode(updated) {
                try? data.write(to: url, options: .atomic)
            }
            reconcile(old, updated)
        }
    }

    private func decode(_ data: Data?) -> DesiredShield {
        guard let data,
              let value = try? PropertyListDecoder().decode(DesiredShield.self, from: data)
        else { return .empty }
        return value
    }
}
