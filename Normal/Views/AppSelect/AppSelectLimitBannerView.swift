import FamilyControls
import SwiftUI

struct AppSelectLimitBannerView: View {
    let selection: FamilyActivitySelection
    var customDomains: [String] = []
    var customDomainsEnabled = false

    static let warningThreshold = ScreenTimeLimits.maxBlockedItems

    private var itemCount: Int {
        selection.count + customDomains.count
    }

    private var exampleText: String {
        customDomainsEnabled
            ? "5 Apps + 1 Category + 5 Websites + 10 Custom Domains = 21 items"
            : "5 Apps + 1 Category + 5 Websites = 11 items"
    }

    var body: some View {
        if itemCount >= Self.warningThreshold {
            Section {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: DS.Spacing.xs - 2) {
                            Text("Too many items selected.").font(.headline)
                            Text("\(itemCount) items selected")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(
                        customDomainsEnabled
                            ? "Apple's Screen Time framework caps how many items can be blocked at once. 50+ items can't be blocked. Each app, website, category, and custom domain counts as one item."
                            : "Apple's Screen Time framework caps how many items can be blocked at once. 50+ items can't be blocked. Each app, website, and category counts as one item."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Example").font(.caption.weight(.semibold))
                        Text(exampleText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("How to reduce your selection:").font(.subheadline.weight(.semibold))
                        BulletRow(text: "Delete apps and bloatware you don't use")
                        BulletRow(text: "Block the App Store to prevent reinstalls")
                        BulletRow(text: "Use categories in the app picker")
                    }
                }
                .padding(.vertical, DS.Spacing.xs)
            }
        }
    }
}
