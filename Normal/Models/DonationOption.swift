import Foundation

enum DonationCadence: String, CaseIterable, Identifiable {
    case oneTime
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneTime: "One-time"
        case .monthly: "Monthly"
        }
    }

    var productKeyword: String {
        switch self {
        case .oneTime: "onetime"
        case .monthly: "monthly"
        }
    }
}

struct DonationOption: Identifiable, Equatable {
    let amount: Int
    let cadence: DonationCadence

    var id: String { productID }

    var productID: String {
        "\(DonationCatalog.productPrefix).\(cadence.productKeyword).\(amount)"
    }

    var displayAmount: String { "$\(amount)" }
}

enum DonationCatalog {
    static let productPrefix = "org.normalengineering.Normal.donation"

    static func amounts(for cadence: DonationCadence) -> [Int] {
        switch cadence {
        case .oneTime: [5, 10, 20, 50, 100, 200]
        case .monthly: [5, 10, 20]
        }
    }

    static func options(for cadence: DonationCadence) -> [DonationOption] {
        amounts(for: cadence).map { DonationOption(amount: $0, cadence: cadence) }
    }

    static var allProductIDs: [String] {
        DonationCadence.allCases.flatMap { cadence in
            options(for: cadence).map(\.productID)
        }
    }
}
