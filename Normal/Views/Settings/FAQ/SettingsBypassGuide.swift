import SwiftUI

struct SettingsBypassGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            disclaimer
            Text("Yes! Fixing the Settings bypass is straightforward using Apple's Shortcuts app.")
            stepOne
            stepTwo
            stepThree
            howItWorks
            importantNotes
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
            Text("This ensures it runs silently in the background every time.")
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
                        BulletRow(text: "Using an NFC or QR key you've configured in Normal", indent: DS.Spacing.lg)
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
