import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

struct SelectAppsForGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var selectedApps: [SelectedApps]

    @Binding var selection: FamilyActivitySelection

    @State private var workingSelection = FamilyActivitySelection()

    private var mainSelection: FamilyActivitySelection? {
        selectedApps.first?.selection
    }

    private var workingCount: Int {
        workingSelection.applicationTokens.count + workingSelection.webDomainTokens.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if let source = mainSelection,
                   !source.applicationTokens.isEmpty || !source.webDomainTokens.isEmpty || !source.categoryTokens.isEmpty
                {
                    List {
                        if !source.categoryTokens.isEmpty {
                            Section("Categories") {
                                let sortedCategories = sortTokens(tokens: tokenToHashableArray(tokens: source.categoryTokens))
                                ForEach(sortedCategories, id: \.self) { token in
                                    row(for: token)
                                }
                            }
                        }

                        if !source.applicationTokens.isEmpty {
                            Section("Apps") {
                                let sortedApps = sortTokens(tokens: tokenToHashableArray(tokens: source.applicationTokens))
                                ForEach(sortedApps, id: \.self) { token in
                                    row(for: token)
                                }
                            }
                        }
                        if !source.webDomainTokens.isEmpty {
                            Section("Websites") {
                                let sortedDomains = sortTokens(tokens: tokenToHashableArray(tokens: source.webDomainTokens))
                                ForEach(sortedDomains, id: \.self) { token in
                                    row(for: token)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                } else {
                    ContentUnavailableView(
                        "No Apps Available",
                        systemImage: "apps.iphone",
                        description: Text("Select apps in the main picker first.")
                    )
                }
            }
            .navigationTitle("Select Apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selection = workingSelection
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            workingSelection = selection
        }
    }

    private func row(for token: some Hashable) -> some View {
        let selected = isSelected(token)
        return SelectAppForGroupRowView(
            token: token as AnyHashable,
            isSelected: selected
        ) {
            toggle(token)
        }
        .overlay(alignment: .trailing) {
            if selected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
    }

    private func isSelected(_ token: some Hashable) -> Bool {
        if let app = token as? ApplicationToken {
            return workingSelection.applicationTokens.contains(app)
        } else if let web = token as? WebDomainToken {
            return workingSelection.webDomainTokens.contains(web)
        } else if let cat = token as? ActivityCategoryToken {
            return workingSelection.categoryTokens.contains(cat)
        }
        return false
    }

    private func toggle(_ token: some Hashable) {
        if let app = token as? ApplicationToken {
            if workingSelection.applicationTokens.contains(app) {
                workingSelection.applicationTokens.remove(app)
            } else {
                workingSelection.applicationTokens.insert(app)
            }
        } else if let web = token as? WebDomainToken {
            if workingSelection.webDomainTokens.contains(web) {
                workingSelection.webDomainTokens.remove(web)
            } else {
                workingSelection.webDomainTokens.insert(web)
            }
        } else if let cat = token as? ActivityCategoryToken {
            if workingSelection.categoryTokens.contains(cat) {
                workingSelection.categoryTokens.remove(cat)
            } else {
                workingSelection.categoryTokens.insert(cat)
            }
        }
    }
}
