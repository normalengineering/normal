import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

struct SelectAppsForGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var selectedApps: [SelectedApps]

    @Binding var selection: FamilyActivitySelection
    @State private var workingSelection = FamilyActivitySelection()
    @State private var sortedCategories: [ActivityCategoryToken] = []
    @State private var sortedApps: [ApplicationToken] = []
    @State private var sortedDomains: [WebDomainToken] = []

    private var mainSelection: FamilyActivitySelection? {
        selectedApps.first?.selection
    }

    private var hasContent: Bool {
        !sortedCategories.isEmpty || !sortedApps.isEmpty || !sortedDomains.isEmpty
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Select Apps")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
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
        .onAppear(perform: prepare)
    }

    @ViewBuilder
    private var content: some View {
        if hasContent {
            List {
                tokenSection(title: "Categories", tokens: sortedCategories)
                tokenSection(title: "Apps", tokens: sortedApps)
                tokenSection(title: "Websites", tokens: sortedDomains)
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

    @ViewBuilder
    private func tokenSection<T: Hashable>(title: LocalizedStringKey, tokens: [T]) -> some View {
        if !tokens.isEmpty {
            Section(title) {
                ForEach(tokens, id: \.self) { token in
                    row(for: token)
                }
            }
        }
    }

    private func row(for token: some Hashable) -> some View {
        let selected = isSelected(token)
        return SelectAppForGroupRowView(
            token: token as AnyHashable,
            isSelected: selected,
            action: { toggle(token) }
        )
        .overlay(alignment: .trailing) {
            if selected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
    }

    private func prepare() {
        if let mainSelection, selection.isSubset(of: mainSelection) {
            workingSelection = selection
        } else {
            workingSelection = FamilyActivitySelection()
        }
        if let mainSelection {
            sortedCategories = mainSelection.categoryTokens.sortedStably
            sortedApps = mainSelection.applicationTokens.sortedStably
            sortedDomains = mainSelection.webDomainTokens.sortedStably
        }
    }

    private func isSelected(_ token: some Hashable) -> Bool {
        if let app = token as? ApplicationToken {
            workingSelection.applicationTokens.contains(app)
        } else if let web = token as? WebDomainToken {
            workingSelection.webDomainTokens.contains(web)
        } else if let cat = token as? ActivityCategoryToken {
            workingSelection.categoryTokens.contains(cat)
        } else {
            false
        }
    }

    private func toggle(_ token: some Hashable) {
        if let app = token as? ApplicationToken {
            workingSelection.applicationTokens.toggle(app)
        } else if let web = token as? WebDomainToken {
            workingSelection.webDomainTokens.toggle(web)
        } else if let cat = token as? ActivityCategoryToken {
            workingSelection.categoryTokens.toggle(cat)
        }
    }
}

private extension Set {
    mutating func toggle(_ element: Element) {
        if contains(element) { remove(element) } else { insert(element) }
    }
}
