import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

struct GroupListCardView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(\.modelContext) private var modelContext
    @Query private var appGroups: [AppGroup]

    let appGroup: AppGroup
    let displayLimit = 3

    private var allTokens: [AnyHashable] { allTokensFromSelection(selection: appGroup.selection) }

    var body: some View {
        CardView {
            Text(appGroup.name)
                .font(.headline)
            HStack {
                groupIconView
                Spacer()
                Text("\(allTokens.count) total")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .contextMenu {
            toggleBlockedStatusButtonView
            Button(role: .destructive) {
                modelContext.delete(appGroup)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var toggleBlockedStatusButtonView: some View {
        let text = appGroup.isBlocked ? "Unblock" : "Block"
        let icon = appGroup.isBlocked ? "lock.open" : "lock"
        return Button(role: .confirm) {
            appGroup.toggleBlockedStatus()
            screenTimeService.setShieldOnGroup(selection: appGroup.selection, shouldBlock: appGroup.isBlocked)
        } label: {
            Label(text, systemImage: icon)
        }
    }

    private var groupIconView: some View {
        let allTokens = allTokensFromSelection(selection: appGroup.selection)
        let iconsToShow = allTokens.prefix(displayLimit)

        return HStack(spacing: -4) {
            ForEach(iconsToShow, id: \.self) { token in
                Group {
                    if let appToken = token as? ApplicationToken {
                        Label(appToken)
                    } else if let categoryToken = token as? ActivityCategoryToken {
                        Label(categoryToken)
                    } else if let webDomainToken = token as? WebDomainToken {
                        Label(webDomainToken)
                    }
                }
                .labelStyle(.iconOnly)
            }

            if allTokens.count > displayLimit {
                moreIndicator
            }
        }
    }

    private var moreIndicator: some View {
        Text("+\(allTokens.count - displayLimit)")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }
}
