import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

struct SelectAppsForGroupSheet: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var selectedApps: [SelectedApps]
    private var mainSelection: SelectedApps? { selectedApps.first }

    @Binding var currentGroupSelection: FamilyActivitySelection

    var body: some View {
        NavigationStack {
            List {
                if let selection = mainSelection?.selection {
                    if !selection.applicationTokens.isEmpty { Section("Apps") {
                        ForEach(Array(selection.applicationTokens), id: \.self) { token in
                            appRow(token: token)
                        }
                    }
                    }
                    if !selection.webDomainTokens.isEmpty { Section("Web Domains") {
                        ForEach(Array(selection.webDomainTokens), id: \.self) { token in
                            appRow(token: token)
                        }
                    }
                    }
                } else {
                    ContentUnavailableView("No Source Apps", systemImage: "apps.iphone", description: Text("Select apps in the main picker first."))
                }
            }
            .navigationTitle("Select Apps")
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.insetGrouped)
        }
    }

    // MARK: - Logic Helpers

    private func isAppSelected(token: AnyHashable) -> Bool {
        if let appToken = token as? ApplicationToken {
            return currentGroupSelection.applicationTokens.contains(appToken)
        } else if let webDomainToken = token as? WebDomainToken {
            return currentGroupSelection.webDomainTokens.contains(webDomainToken)
        } else { return false }
    }

    private func toggleAppSelect(token: AnyHashable) {
        if let appToken = token as? ApplicationToken {
            if currentGroupSelection.applicationTokens.contains(appToken) {
                currentGroupSelection.applicationTokens.remove(appToken)
            } else {
                currentGroupSelection.applicationTokens.insert(appToken)
            }
        } else if let webDomainToken = token as? WebDomainToken {
            if currentGroupSelection.webDomainTokens.contains(webDomainToken) {
                currentGroupSelection.webDomainTokens.remove(webDomainToken)
            } else {
                currentGroupSelection.webDomainTokens.insert(webDomainToken)
            }
        }
    }

    private func appRow(token: AnyHashable) -> some View {
        return SelectAppForGroupRowView(token: token, isSelected: isAppSelected(token: token)) {
            toggleAppSelect(token: token)
        }
    }
}
