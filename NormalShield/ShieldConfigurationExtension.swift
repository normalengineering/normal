import FamilyControls
import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let sharedStore = SharedStore()

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let limited = reachedLimitSelection()
        return makeConfiguration(
            subject: "app",
            isDailyLimit: application.token.map(limited.applicationTokens.contains) ?? false
        )
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        let limited = reachedLimitSelection()
        return makeConfiguration(
            subject: "app",
            isDailyLimit: (application.token.map(limited.applicationTokens.contains) ?? false)
                || (category.token.map(limited.categoryTokens.contains) ?? false)
        )
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        let limited = reachedLimitSelection()
        return makeConfiguration(
            subject: "website",
            isDailyLimit: webDomain.token.map(limited.webDomainTokens.contains) ?? false
        )
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        let limited = reachedLimitSelection()
        return makeConfiguration(
            subject: "website",
            isDailyLimit: (webDomain.token.map(limited.webDomainTokens.contains) ?? false)
                || (category.token.map(limited.categoryTokens.contains) ?? false)
        )
    }

    /// Union of every spent Max Daily Limit — the same set the Monitor applies to the `.dailyLimits` store.
    private func reachedLimitSelection() -> FamilyActivitySelection {
        sharedStore.reachedUsageLimits()
            .compactMap { try? FamilyActivitySelection.fromData($0.selectionData) }
            .reduce(FamilyActivitySelection()) { $0.union($1) }
    }

    private func makeConfiguration(subject: String, isDailyLimit: Bool) -> ShieldConfiguration {
        let subtitle = isDailyLimit
            ? "You've reached your max daily limit."
            : "If you need to use this \(subject), unblock with a key in Normal."

        return ShieldConfiguration(
            backgroundBlurStyle: .dark,
            backgroundColor: .black,
            title: ShieldConfiguration.Label(text: "Blocked by Normal", color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: .lightGray),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: .black),
            primaryButtonBackgroundColor: .white
        )
    }
}
