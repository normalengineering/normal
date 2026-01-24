import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

struct AppGroupListCardView: View {
    @Environment(\.modelContext) private var modelContext

    let appGroup: AppGroup
    let displayLimit = 3
    private var tokens: [ApplicationToken] {
        Array(appGroup.selection.applicationTokens)
    }

    var body: some View {
        CardView() {
            Text(appGroup.name)
                .font(.headline)
            HStack {
                groupIconView
                Spacer()
                Text("\(appGroup.selection.applicationTokens.count) apps")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(appGroup)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var groupIconView: some View {
        let appsToShow = tokens.prefix(displayLimit)

        return HStack(spacing: -4) {
            ForEach(appsToShow, id: \.self) { app in
                Label(app)
                    .labelStyle(.iconOnly)
            }

            if tokens.count > displayLimit {
                moreIndicator
            }
        }
    }

    private var moreIndicator: some View {
        Text("+\(tokens.count - displayLimit)")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }
}
