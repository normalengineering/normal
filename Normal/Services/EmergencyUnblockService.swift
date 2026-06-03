import Foundation
import Observation

@MainActor
@Observable
final class EmergencyUnblockService {
    private let ledger: any EmergencyUnblockLedger

    init(ledger: any EmergencyUnblockLedger) {
        self.ledger = ledger
    }

    func reconcile(into settings: Settings) {
        apply(Self.merge(settings.emergencyUnblockDates, ledger.load()), to: settings)
    }

    func record(into settings: Settings) {
        let existing = Self.merge(settings.emergencyUnblockDates, ledger.load())
        apply(Self.merge(existing, [.now]), to: settings)
    }

    private func apply(_ dates: [Date], to settings: Settings) {
        settings.emergencyUnblockDates = dates
        ledger.save(dates)
    }

    static func canonical(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: millisecondKey(date).rounded() / 1000)
    }

    private static func millisecondKey(_ date: Date) -> Double {
        date.timeIntervalSinceReferenceDate * 1000
    }

    static func merge(_ lhs: [Date], _ rhs: [Date]) -> [Date] {
        var seen = Set<Int64>()
        var result: [Date] = []
        for date in lhs + rhs {
            if seen.insert(Int64(millisecondKey(date).rounded())).inserted {
                result.append(canonical(date))
            }
        }
        return result.sorted()
    }
}
