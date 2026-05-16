import SwiftUI

enum FAQAnswer {
    static let body: Font = .body

    static let isNormalFree = AnyView(
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Yes, it shouldn't cost anything to use your phone less.")
            Text("Normal is 100% free with no in-app purchases, subscriptions, or hidden fees. It's an open-source project and the source code is available on GitHub for you to modify and tinker with.")
        }
        .font(body)
        .foregroundStyle(.secondary)
    )

    static let privacyFriendly = AnyView(
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("We don't collect or sell any data. You can view the source code to verify this yourself.")
            Text("There are no accounts, no internet connection required, and no data logging.")
            Text("Normal uses Apple's Screen Time API and the Managed Settings framework to enforce app limits entirely on your device. All blocking rules, schedules, and configurations are stored locally, nothing is ever sent to a server.")
        }
        .font(body)
        .foregroundStyle(.secondary)
    )

    static let bugsWithoutCollection = AnyView(
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("We rely on community feedback and contributions to identify issues and implement improvements.")
            Text("Since all data remains on your device, we can't gather usage statistics. Instead, we encourage users to report bugs and suggest features directly through our GitHub repository.")
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("You can also reach us at")
                Link("info@normalengineering.org", destination: URL(string: "mailto:info@normalengineering.org")!)
                    .foregroundStyle(.tint)
                Text("if you have anything you'd like to report.")
            }
        }
        .font(body)
        .foregroundStyle(.secondary)
    )

    static let worksOffline = AnyView(
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Yes, everything runs locally on your iPhone.")
            Text("Normal works fully offline. No internet connection is required to set up or enforce your screen time limits.")
        }
        .font(body)
        .foregroundStyle(.secondary)
    )

    static let vsAppleScreenTime = AnyView(
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Apple's Screen Time").fontWeight(.medium).foregroundStyle(.primary)
                Text("works on an opt-out basis. When you hit a limit, you're simply asked whether to continue or not. It's easy to dismiss with a single tap, easy to bypass with a passcode, and tedious to set up.")
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Normal").fontWeight(.medium).foregroundStyle(.primary)
                Text("takes an opt-in approach. Apps you select are blocked by default. To use them, you have to physically scan an NFC tag or QR code you've placed somewhere intentional.")
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                BulletRow(text: "Stronger, harder-to-bypass blocking")
                BulletRow(text: "Can be made completely impossible to bypass")
                BulletRow(text: "As strict or as flexible as you choose")
            }
        }
        .font(body)
        .foregroundStyle(.secondary)
    )

    static let vsOtherApps = AnyView(
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Aside from being completely free and open source, Normal is built to be much stronger and better serve its purpose.")
            FAQHeadedParagraph(
                title: "Opt-in approach",
                text: "Most screen time apps use an opt-out approach, like Apple's Screen Time, where you're asked to confirm each time you exceed a limit. With Normal, selected apps are blocked by default. To use them, you have to physically scan an NFC tag or QR code you've placed somewhere intentional."
            )
            FAQHeadedParagraph(
                title: "Physical layer",
                text: "However hard you make it to scan your key is however hard it is to use your phone."
            )
            FAQHeadedParagraph(
                title: "Timed unblocks",
                text: "Other apps require you to manually reblock when you're done, and users commonly report forgetting to reblock or falling back into doom-scrolling. With Normal, set a timed unblock for 15 minutes and you'll be automatically blocked again when it's up. Going to an event where you need to stay reachable? Unblock for a few hours and Normal handles the rest."
            )
            FAQHeadedParagraph(
                title: "App groups",
                text: "Only need to unblock Instagram to post quickly? Create an app group for it. Select a 15-minute unblock and only the apps you need will be available, no excuse to check anything else. Complete granular control with Normal."
            )
        }
        .font(body)
        .foregroundStyle(.secondary)
    )

    static let contribute = AnyView(
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Absolutely. Normal is fully open source and we welcome contributions of all kinds:")
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                BulletRow(text: "Code")
                BulletRow(text: "Design")
                BulletRow(text: "Documentation")
                BulletRow(text: "Bug reports")
            }
            Text("Head to our GitHub repository to get started, check out open issues, or submit a pull request.")
        }
        .font(body)
        .foregroundStyle(.secondary)
    )

    static let dumbphone = AnyView(
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Absolutely, Normal was designed for exactly this.")
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                NumberedRow(number: 1, text: "Uninstall all unnecessary apps")
                NumberedRow(number: 2, text: "Select Safari and the App Store in Normal")
                NumberedRow(number: 3, text: "Block them all")
            }
            Text("Now you have a dumb phone with iPhone hardware, the best of both worlds.")
        }
        .font(body)
        .foregroundStyle(.secondary)
    )

    static let reselectAppLimitation = AnyView(
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("This is an Apple limitation, not a Normal one.")
            Text("Apple's Screen Time API is restrictive for privacy reasons. The app-selection pop-over is made by Apple, not us, and is the only way to select apps for Screen Time.")
            Text("Here's the technical reason:")
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                BulletRow(text: "Apple creates a random ID for each app every time you use the picker")
                BulletRow(text: "Developers aren't told which apps were previously selected")
                BulletRow(text: "There's no way for us to carry over your previous selections automatically")
            }
            Text("We require reselecting schedules and groups to ensure Normal's groups, apps, and timed unlocks work consistently. We wish we could make this smoother, but Apple enforces this strictly to protect user privacy.")
        }
        .font(body)
        .foregroundStyle(.secondary)
    )

    static let settingsBypass = AnyView(SettingsBypassGuide())

    static let contact = AnyView(
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("We'd love to hear from you, whether it's a bug, a feature idea, or a question.")
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Email us at")
                Link("info@normalengineering.org", destination: URL(string: "mailto:info@normalengineering.org")!)
                    .foregroundStyle(.tint)
            }
            Text("Or raise an issue on our GitHub repository.")
        }
        .font(body)
        .foregroundStyle(.secondary)
    )

    static let keyTypes = AnyView(KeyTypesFAQView())
}

private struct FAQHeadedParagraph: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title).font(.headline).foregroundStyle(.primary)
            Text(text)
        }
    }
}
