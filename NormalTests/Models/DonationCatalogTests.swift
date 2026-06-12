import Foundation
@testable import Normal
import Testing

struct DonationCatalogTests {
    @Test func amountsAreTheExpectedTiers() {
        #expect(DonationCatalog.amounts(for: .oneTime) == [5, 10, 20, 50, 100, 200])
        #expect(DonationCatalog.amounts(for: .monthly) == [5, 10, 20])
    }

    @Test func optionsCoverEveryAmountForCadence() {
        let oneTime = DonationCatalog.options(for: .oneTime)
        #expect(oneTime.map(\.amount) == [5, 10, 20, 50, 100, 200])
        #expect(oneTime.allSatisfy { $0.cadence == .oneTime })

        let monthly = DonationCatalog.options(for: .monthly)
        #expect(monthly.map(\.amount) == [5, 10, 20])
        #expect(monthly.allSatisfy { $0.cadence == .monthly })
    }

    @Test func productIDEncodesCadenceAndAmount() {
        #expect(
            DonationOption(amount: 20, cadence: .oneTime).productID
                == "org.normalengineering.Normal.donation.onetime.20"
        )
        #expect(
            DonationOption(amount: 10, cadence: .monthly).productID
                == "org.normalengineering.Normal.donation.monthly.10"
        )
    }

    @Test func allProductIDsAreUniqueAcrossCadences() {
        let ids = DonationCatalog.allProductIDs
        let expectedCount = DonationCadence.allCases
            .reduce(0) { $0 + DonationCatalog.amounts(for: $1).count }
        #expect(ids.count == expectedCount)
        #expect(Set(ids).count == ids.count)
    }

    @Test func displayAmountIsDollarFormatted() {
        #expect(DonationOption(amount: 50, cadence: .oneTime).displayAmount == "$50")
    }
}
