import SwiftData
import SwiftUI

struct MainBlockButtonView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService

    let mainSelection: SelectedApps

    @State private var authAction: (@MainActor () -> Void)?
    @State private var allowBypass: Bool = false

    private var blockStatus: BlockStatus {
        screenTimeService.blockStatus(selection: mainSelection.selection)
    }

    var body: some View {
        Section {
            if blockStatus != .all {
                Button {
                    allowBypass = true
                    authAction = {
                        screenTimeService.applyShieldOnAll(selection: mainSelection.selection)
                    }
                } label: {
                    HStack {
                        Label("Block All", systemImage: "lock.fill")
                            .foregroundStyle(.blue)
                        Spacer()
                    }
                }
                .padding(.vertical, 8)
            }

            if blockStatus != .none {
                Button {
                    allowBypass = false
                    authAction = {
                        screenTimeService.removeShieldOnAll()
                    }
                } label: {
                    HStack {
                        Label("Unblock All", systemImage: "lock.open.fill")
                            .foregroundStyle(.red)
                        Spacer()
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .keySelect(action: $authAction, allowBypass: allowBypass)
    }
}
