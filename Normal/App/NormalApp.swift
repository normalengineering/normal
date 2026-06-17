import FamilyControls
import SwiftData
import SwiftUI

@main
struct NormalApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            AppGroup.self,
            SelectedApps.self,
            Key.self,
            BlockSchedule.self,
            Settings.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: UITestSupport.isActive
        )
        let container = try! ModelContainer(for: schema, configurations: configuration)

        let context = container.mainContext
        let descriptor = FetchDescriptor<Settings>()
        if (try? context.fetchCount(descriptor)) == 0 {
            let settings = Settings()
            settings.hasCompletedOnboarding = UITestSupport.skipOnboarding
            settings.enableCustomDomains = UITestSupport.customDomains
            context.insert(settings)
        }

        if UITestSupport.isActive {
            context.insert(SelectedApps(selection: FamilyActivitySelection()))
            if !UITestSupport.noKeys {
                context.insert(Key(name: "Test Key", type: .qr, rawValue: UITestSupport.stubScanValue))
            }
            if UITestSupport.seedSchedule {
                context.insert(BlockSchedule(
                    name: "Test Schedule",
                    selection: FamilyActivitySelection(),
                    startHour: 9,
                    startMinute: 0,
                    durationMinutes: 60,
                    weekdays: [2, 3, 4, 5, 6],
                    shouldBlock: true,
                    isTimed: false,
                    isEnabled: true
                ))
            }
        }

        modelContainer = container
    }

    var body: some Scene {
        WindowGroup {
            AppContainer()
        }
        .modelContainer(modelContainer)
    }
}
