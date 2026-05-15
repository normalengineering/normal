import SwiftUI

struct FAQView: View {
    @State private var expandedItem: Int? = nil

    var body: some View {
        List {
            ForEach(Array(faqItems.enumerated()), id: \.offset) { index, item in
                FAQItem(
                    question: item.question,
                    answer: item.answer,
                    isExpanded: expandedItem == index
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        expandedItem = expandedItem == index ? nil : index
                    }
                }
            }
        }
    }
}

struct FAQItem: View {
    let question: String
    let answer: AnyView
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack {
                    Text(question)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                answer
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

struct FAQEntry {
    let question: String
    let answer: AnyView
}

private let faqItems: [FAQEntry] = [
    FAQEntry(
        question: "Is Normal really free?",
        answer: AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Yes, it shouldn't cost anything to use your phone less.")
                Text("Normal is 100% free with no in-app purchases, subscriptions, or hidden fees. It's an open-source project and the source code is available on GitHub for you to modify and tinker with.")
            }
            .font(.body)
            .foregroundColor(.secondary)
        )
    ),

    FAQEntry(
        question: "Is it really privacy friendly?",
        answer: AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("We don't collect or sell any data. You can view the source code to verify this yourself.")
                Text("There are no accounts, no internet connection required, and no data logging.")
                Text("Normal uses Apple's Screen Time API and the Managed Settings framework to enforce app limits entirely on your device. All blocking rules, schedules, and configurations are stored locally, nothing is ever sent to a server.")
            }
            .font(.body)
            .foregroundColor(.secondary)
        )
    ),

    FAQEntry(
        question: "How does Normal fix bugs and improve without data collection?",
        answer: AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("We rely on community feedback and contributions to identify issues and implement improvements.")
                Text("Since all data remains on your device, we can't gather usage statistics. Instead, we encourage users to report bugs and suggest features directly through our GitHub repository.")
                VStack(alignment: .leading, spacing: 4) {
                    Text("You can also reach us at")
                    Link("info@normalengineering.org", destination: URL(string: "mailto:info@normalengineering.org")!)
                        .foregroundColor(.accentColor)
                    Text("if you have anything you'd like to report.")
                }
            }
            .font(.body)
            .foregroundColor(.secondary)
        )
    ),

    FAQEntry(
        question: "Does Normal work without an internet connection?",
        answer: AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Yes, everything runs locally on your iPhone.")
                Text("Normal works fully offline. No internet connection is required to set up or enforce your screen time limits.")
            }
            .font(.body)
            .foregroundColor(.secondary)
        )
    ),

    FAQEntry(
        question: "How is Normal different from Apple's built-in Screen Time?",
        answer: AnyView(
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple's Screen Time")
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("works on an opt-out basis. When you hit a limit, you're simply asked whether to continue or not. It's easy to dismiss with a single tap, easy to bypass with a passcode, and tedious to set up.")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Normal")
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("takes an opt-in approach. Apps you select are blocked by default. To use them, you have to physically scan an NFC tag or QR code you've placed somewhere intentional.")
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundColor(.secondary)
                        Text("Stronger, harder-to-bypass blocking")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundColor(.secondary)
                        Text("Can be made completely impossible to bypass")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundColor(.secondary)
                        Text("As strict or as flexible as you choose")
                    }
                }
            }
            .font(.body)
            .foregroundColor(.secondary)
        )
    ),

    FAQEntry(
        question: "How is Normal different from the other screen time apps?",
        answer: AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Aside from being completely free and open source, Normal is built to be much stronger and better serve its purpose.")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Opt-in approach")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Most screen time apps use an opt-out approach, like Apple's Screen Time, where you're asked to confirm each time you exceed a limit. With Normal, selected apps are blocked by default. To use them, you have to physically scan an NFC tag or QR code you've placed somewhere intentional.")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Physical layer")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("However hard you make it to scan your key is however hard it is to use your phone.")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Timed unblocks")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Other apps require you to manually reblock when you're done, and users commonly report forgetting to reblock or falling back into doom-scrolling. With Normal, set a timed unblock for 15 minutes and you'll be automatically blocked again when it's up. Going to an event where you need to stay reachable? Unblock for a few hours and Normal handles the rest.")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("App groups")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Only need to unblock Instagram to post quickly? Create an app group for it. Select a 15-minute unblock and only the apps you need will be available, no excuse to check anything else. Complete granular control with Normal.")
                }
            }
            .font(.body)
            .foregroundColor(.secondary)
        )
    ),

    FAQEntry(
        question: "Can I contribute to the project?",
        answer: AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Absolutely. Normal is fully open source and we welcome contributions of all kinds:")
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundColor(.secondary)
                        Text("Code")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundColor(.secondary)
                        Text("Design")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundColor(.secondary)
                        Text("Documentation")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundColor(.secondary)
                        Text("Bug reports")
                    }
                }
                Text("Head to our GitHub repository to get started, check out open issues, or submit a pull request.")
            }
            .font(.body)
            .foregroundColor(.secondary)
        )
    ),

    FAQEntry(
        question: "Can I use Normal to make my iPhone a dumbphone or semi-dumb feature phone?",
        answer: AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Absolutely, Normal was designed for exactly this.")
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("1.").foregroundColor(.secondary)
                        Text("Uninstall all unnecessary apps")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("2.").foregroundColor(.secondary)
                        Text("Select Safari and the App Store in Normal")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("3.").foregroundColor(.secondary)
                        Text("Block them all")
                    }
                }
                Text("Now you have a dumb phone with iPhone hardware, the best of both worlds.")
            }
            .font(.body)
            .foregroundColor(.secondary)
        )
    ),

    FAQEntry(
        question: "Why do I have to reselect apps in my schedules and groups when I update my selected apps?",
        answer: AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("This is an Apple limitation, not a Normal one.")
                Text("Apple's Screen Time API is restrictive for privacy reasons. The app-selection pop-over is made by Apple, not us, and is the only way to select apps for Screen Time.")
                Text("Here's the technical reason:")
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundColor(.secondary)
                        Text("Apple creates a random ID for each app every time you use the picker")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundColor(.secondary)
                        Text("Developers aren't told which apps were previously selected")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundColor(.secondary)
                        Text("There's no way for us to carry over your previous selections automatically")
                    }
                }
                Text("We require reselecting schedules and groups to ensure Normal's groups, apps, and timed unlocks work consistently. We wish we could make this smoother, but Apple enforces this strictly to protect user privacy.")
            }
            .font(.body)
            .foregroundColor(.secondary)
        )
    ),

    FAQEntry(
        question: "Can I prevent disabling Normal via Settings? I want to make it impossible to access blocked apps.",
        answer: AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text("Yes! Fixing the Settings bypass is straightforward using Apple's Shortcuts app.")

                VStack(alignment: .leading, spacing: 12) {
                    Text("Step 1: Create the automation")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("1.").foregroundColor(.secondary)
                            Text("Open the Shortcuts app")
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("2.").foregroundColor(.secondary)
                            Text("Go to the Automation tab")
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("3.").foregroundColor(.secondary)
                            Text("Tap the + button to create a new automation")
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("4.").foregroundColor(.secondary)
                            Text("Set the trigger to \"When Settings is closed\"")
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("5.").foregroundColor(.secondary)
                            Text("Set the action to \"Go to Home Screen\"")
                        }
                    }

                    HStack(spacing: 12) {
                        Image("SettingsBypassStep1")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 150)
                            .cornerRadius(12)
                            .clipped()

                        Image("SettingsBypassStep2")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 150)
                            .cornerRadius(12)
                            .clipped()
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Step 2: Set it to run automatically")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundColor(.secondary)
                            Text("Set the automation to Run Immediately")
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundColor(.secondary)
                            Text("Turn off Notify When Run")
                        }
                    }

                    Text("This ensures it runs silently in the background every time.")
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Step 3: Block the Shortcuts app in Normal")
                        .font(.headline)

                    Text("Add Shortcuts to your selected apps in Normal so the automation itself can't be easily modified.")

                    Image("SettingsBypassStep3")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 200)
                        .cornerRadius(12)
                        .clipped()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("How it works")
                        .font(.headline)

                    Text("Screen Time opens authentication in Settings. The automation detects Settings closing and immediately returns you to the Home Screen, preventing you from reaching the disable option.")

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundColor(.secondary)
                            Text("You may need to enable Face ID for this to work")
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundColor(.secondary)
                            Text("You can still access other device settings normally")
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Important notes")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundColor(.secondary)
                            Text("When you update your selected apps in Normal, you'll need to reselect apps in your schedules and groups due to an Apple Screen Time limitation.")
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("•").foregroundColor(.secondary)
                                Text("After this setup, the only ways to disable Normal are:")
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text("  •").foregroundColor(.secondary)
                                    Text("Using an NFC or QR key you've configured in Normal")
                                }
                                HStack(alignment: .top, spacing: 8) {
                                    Text("  •").foregroundColor(.secondary)
                                    Text("Resetting your device")
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("•").foregroundColor(.secondary)
                                Text("Unblocking Shortcuts or all apps won't turn off this automation. To manage it:")
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text("  •").foregroundColor(.secondary)
                                    Text("To disable: Unblock Shortcuts, then manually turn off the automation")
                                }
                                HStack(alignment: .top, spacing: 8) {
                                    Text("  •").foregroundColor(.secondary)
                                    Text("To re-enable: Unblock Shortcuts, turn the automation back on, then re-block Shortcuts")
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .font(.body)
            .foregroundColor(.secondary)
        )
    )
]