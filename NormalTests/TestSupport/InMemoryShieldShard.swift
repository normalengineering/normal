import FamilyControls
import ManagedSettings
@testable import Normal

final class InMemoryShieldShard: ShieldShard {
    var applications: Set<ApplicationToken>?
    var webDomains: Set<WebDomainToken>?
    var categoryTokens: Set<ActivityCategoryToken> = []
    var denyAppRemoval = false
}
