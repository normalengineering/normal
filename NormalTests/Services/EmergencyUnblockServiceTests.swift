import Foundation
@testable import Normal
import Testing

@MainActor
struct EmergencyUnblockServiceTests {
    private func makeService(
        ledger: InMemoryEmergencyUnblockLedger = InMemoryEmergencyUnblockLedger()
    ) -> (EmergencyUnblockService, InMemoryEmergencyUnblockLedger) {
        (EmergencyUnblockService(ledger: ledger), ledger)
    }

    private func date(_ seconds: Double) -> Date {
        Date(timeIntervalSinceReferenceDate: seconds)
    }

    @Test func recordWritesThroughToBothStores() {
        let (service, ledger) = makeService()
        let settings = Settings()

        service.record(into: settings)

        #expect(settings.emergencyUnblockDates.count == 1)
        #expect(ledger.load().count == 1)
        #expect(settings.emergencyUnblockDates == ledger.load())
    }

    @Test func reconcilePromotesSettingsOnlyToLedger() {
        let (service, ledger) = makeService()
        let settings = Settings()
        settings.emergencyUnblockDates = [date(1000), date(2000)]

        service.reconcile(into: settings)

        #expect(ledger.load().count == 2)
        #expect(settings.emergencyUnblockDates.count == 2)
    }

    @Test func reconcileRestoresFromLedgerOnly() {
        let ledger = InMemoryEmergencyUnblockLedger(dates: [date(1000), date(2000), date(3000)])
        let (service, _) = makeService(ledger: ledger)
        let settings = Settings()

        service.reconcile(into: settings)

        #expect(settings.emergencyUnblockDates.count == 3)
    }

    @Test func reconcileIsIdempotent() {
        let ledger = InMemoryEmergencyUnblockLedger(dates: [date(1000)])
        let (service, _) = makeService(ledger: ledger)
        let settings = Settings()

        service.reconcile(into: settings)
        service.reconcile(into: settings)

        #expect(settings.emergencyUnblockDates.count == 1)
        #expect(ledger.load().count == 1)
    }

    @Test func mergeDedupsSubSecondDrift() {
        let merged = EmergencyUnblockService.merge([date(1000)], [date(1000.0003)])
        #expect(merged.count == 1)
    }

    @Test func mergeUnionsDistinctEvents() {
        let merged = EmergencyUnblockService.merge([date(1000)], [date(1005)])
        #expect(merged.count == 2)
    }

    @Test func recordSelfHealsWhenSettingsStale() {
        let ledger = InMemoryEmergencyUnblockLedger(dates: [date(1000), date(2000)])
        let (service, _) = makeService(ledger: ledger)
        let settings = Settings()

        service.record(into: settings)

        #expect(settings.emergencyUnblockDates.count == 3)
        #expect(ledger.load().count == 3)
    }
}
