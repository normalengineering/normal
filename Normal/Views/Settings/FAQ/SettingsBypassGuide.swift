import SwiftUI

struct SettingsBypassGuide: View {
    @State private var isMethod1Expanded = false
    @State private var isMethod2Expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text("Yes. There are two ways to close the Settings bypass. Pick the one that fits how strict you want to be.")
            disclaimer

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                ExpandableSection(title: "Method 1: Shortcuts automation", isExpanded: $isMethod1Expanded) {
                    method1Content
                }
                ExpandableSection(title: "Method 2: Screen Time passcode", isExpanded: $isMethod2Expanded) {
                    method2Content
                }
            }
        }
        .font(.body)
        .foregroundStyle(.secondary)
    }

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Label("Proceed at your own risk", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("Preventing the Settings bypass is possible, but with it in place the only ways to turn off blocks are through Normal or resetting your phone. If you lock yourself out of your apps, we are not responsible, even if Normal stops working as expected. We are also not responsible for any data loss if you have to reset your device to regain access.")
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(DS.Opacity.muted))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Method 1: Shortcuts automation

    private var method1Content: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text("Use Apple's Shortcuts app to automatically bounce you out of Settings before you can reach the Screen Time toggle.")
            stepOne
            stepTwo
            stepThree
            howItWorks
            importantNotes
        }
    }

    private var stepOne: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Step 1: Create the automation").font(.headline)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                NumberedRow(number: 1, text: "Open the Shortcuts app")
                NumberedRow(number: 2, text: "Go to the Automation tab")
                NumberedRow(number: 3, text: "Tap the + button to create a new automation")
                NumberedRow(number: 4, text: "Set the trigger to \"When Settings is closed\"")
                NumberedRow(number: 5, text: "Set the action to \"Go to Home Screen\"")
            }
            HStack(spacing: DS.Spacing.md) {
                BypassImage(name: "SettingsBypassStep1", maxWidth: 150)
                BypassImage(name: "SettingsBypassStep2", maxWidth: 150)
            }
        }
    }

    private var stepTwo: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Step 2: Set it to run automatically").font(.headline)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                BulletRow(text: "Set the automation to Run Immediately")
                BulletRow(text: "Turn off Notify When Run")
            }
            Text("This ensures it runs immediately every time.")
        }
    }

    private var stepThree: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Step 3: Block the Shortcuts app in Normal").font(.headline)
            Text("Add Shortcuts to your selected apps in Normal so the automation itself can't be easily modified.")
            BypassImage(name: "SettingsBypassStep3", maxWidth: 200)
        }
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("How it works").font(.headline)
            Text("Screen Time opens authentication in Settings. The automation detects Settings closing and immediately returns you to the Home Screen, preventing you from reaching the disable option.")
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                BulletRow(text: "You may need to enable Face ID for this to work")
                BulletRow(text: "You can still access other device settings normally")
            }
        }
    }

    private var importantNotes: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Important notes").font(.headline)
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                BulletRow(text: "When you update your selected apps in Normal, you'll need to reselect apps in your schedules and groups due to an Apple Screen Time limitation.")

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    BulletRow(text: "After this setup, the only ways to disable Normal are:")
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        BulletRow(text: "Using an NFC, QR, or barcode key you've configured in Normal", indent: DS.Spacing.lg)
                        BulletRow(text: "Resetting your device", indent: DS.Spacing.lg)
                    }
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    BulletRow(text: "Unblocking Shortcuts or all apps won't turn off this automation. To manage it:")
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        BulletRow(text: "To disable: Unblock Shortcuts, then manually turn off the automation", indent: DS.Spacing.lg)
                        BulletRow(text: "To re-enable: Unblock Shortcuts, turn the automation back on, then re-block Shortcuts", indent: DS.Spacing.lg)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(DS.Radius.md)
    }

    // MARK: - Method 2: Screen Time passcode

    private var method2Content: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text("Lock Screen Time behind a passcode and Apple ID you don't know. Without them, the Screen Time toggle can't be reached at all.")
            pickOneOption
            whyAppleIdMatters
            passcodeSteps
        }
    }

    private var pickOneOption: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Pick one option for the passcode and Apple ID").font(.headline)
            Text("Any of these works on its own; you only need one.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
            VStack(spacing: DS.Spacing.sm) {
                optionCard(
                    title: Text("Option A: Ask a trusted friend"),
                    body: Text("Hand them your phone so they can enter a passcode and Apple ID that only they know.")
                )
                optionCard(
                    title: Text("Option B: Use a service like [password-locker](https://password-locker.com/)"),
                    body: Text("It provides both a dummy Apple ID and a random passcode. This can be made near impossible to recover.")
                )
                optionCard(
                    title: Text("Option C: Do it yourself"),
                    body: Text("Type in a random passcode and Apple ID password yourself without memorizing them.")
                )
            }
        }
    }

    private var whyAppleIdMatters: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Why the Apple ID matters")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
            Text("Apple lets you reset a forgotten Screen Time passcode using the Apple ID you registered. If that's your own account, you can bypass the lock yourself. Which is why it's important to use credentials you don't have easy access to.")
                .font(.footnote)
                .foregroundStyle(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(DS.Opacity.muted))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(Color.blue.opacity(0.4), lineWidth: 1)
        )
    }

    private var passcodeSteps: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Steps").font(.headline)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                NumberedRow(number: 1, text: "Open Screen Time in Settings")
                NumberedRow(number: 2, text: "Tap \"Lock Screen Time Settings\"")
                passcodeStep3
                NumberedRow(number: 4, text: "Enter an Apple ID for passcode recovery, ideally a second account you don't have the password to")
                NumberedRow(number: 5, text: "Done. Screen Time can no longer be disabled without that passcode or Apple ID login.")
            }
            HStack(spacing: DS.Spacing.md) {
                BypassImage(name: "LockScreenTimeStep1", maxWidth: 110)
                BypassImage(name: "LockScreenTimeStep2", maxWidth: 110)
                BypassImage(name: "LockScreenTimeStep3", maxWidth: 110)
            }
        }
    }

    // Inline markdown link — Text literal init renders [label](url) as a tappable link.
    private var passcodeStep3: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Text("3.")
                .foregroundStyle(.secondary)
            Text("Set a Screen Time passcode (have a friend enter it, use [password-locker](https://password-locker.com/), or type a random PIN yourself)")
        }
    }

    private func optionCard(title: Text, body: Text) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            title
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            body
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

private struct BypassImage: View {
    let name: String
    let maxWidth: CGFloat

    var body: some View {
        Image(name)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: maxWidth)
            .cornerRadius(DS.Radius.md)
            .clipped()
    }
}
