import SwiftData
import SwiftUI

struct EmergencyUnblockView: View {
    let settings: Settings
    @Binding var showConfirmation: Bool
    let performEmergencyUnblock: () -> Void

    @State private var showExplanation = false

    var body: some View {
        List {
            Section {
                Text("\(settings.emergencyUnblocksAvailable) of \(Settings.maxEmergencyUnblocks) remaining")

                Button("Emergency Unblock") {
                    showConfirmation = true
                }
                .disabled(settings.emergencyUnblocksAvailable == 0)
            } header: {
                Text("Emergency Unblock")
            } footer: {
                Text("Removes all blocks immediately without a key. Each use takes 6 months to regenerate.")
            }

            Section {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showExplanation.toggle()
                    }
                } label: {
                    HStack {
                        Text("How Emergency Unblocks Work")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(showExplanation ? 180 : 0))
                            .animation(.easeInOut(duration: 0.3), value: showExplanation)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())

                if showExplanation {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Emergency unblocks provide a way to immediately remove all app blocks when you need access urgently.")
                            .font(.body)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("How it works:")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            VStack(alignment: .leading, spacing: 8) {
                                InfoRow(text: "Each emergency unblock regenerates after exactly 6 months")
                                InfoRow(text: "You get \(Settings.maxEmergencyUnblocks) uses total that replenish over time")
                                InfoRow(text: "All app blocks are removed immediately when used")
                                InfoRow(text: "You can re-block apps afterward, but the emergency unblock takes 6 months to regenerate")
                                InfoRow(text: "Normal is fully offline, so we can't give you more emergency unblocks or reset them")
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Example timeline:")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            VStack(alignment: .leading, spacing: 6) {
                                ExampleRow(time: "Today", action: "Use 1 emergency unblock", remaining: "\(Settings.maxEmergencyUnblocks - 1) left")
                                ExampleRow(time: "3 months", action: "Use another emergency unblock", remaining: "\(Settings.maxEmergencyUnblocks - 2) left")
                                ExampleRow(time: "6 months", action: "First unblock regenerates", remaining: "\(Settings.maxEmergencyUnblocks - 1) left")
                                ExampleRow(time: "9 months", action: "Second unblock regenerates", remaining: "\(Settings.maxEmergencyUnblocks) available")
                            }
                        }


                    }
                    .padding(.vertical, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

struct InfoRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            Text(text)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

struct ExampleRow: View {
    let time: String
    let action: String
    let remaining: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(time)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(action)
                    .font(.body)
                    .foregroundColor(.primary)
                Text(remaining)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.leading, 8)
    }
}