import Foundation
import StoreKit

@MainActor
@Observable
final class DonationService {
    private(set) var products: [String: Product] = [:]
    private(set) var isLoading = false
    private(set) var purchasingProductID: String?
    private(set) var didAttemptLoad = false
    var showThankYou = false
    var errorMessage: String?

    private var updatesTask: Task<Void, Never>?
    private var storefrontTask: Task<Void, Never>?

    init() {
        updatesTask = Task {
            for await update in Transaction.updates {
                guard case let .verified(transaction) = update else { continue }
                await transaction.finish()
            }
        }

        storefrontTask = Task { [weak self] in
            for await _ in Storefront.updates {
                guard let self else { return }
                self.products = [:]
                await self.loadProducts()
            }
        }
    }

    func loadProducts() async {
        guard products.isEmpty, !isLoading else { return }
        isLoading = true
        didAttemptLoad = true
        defer { isLoading = false }
        let requested = DonationCatalog.allProductIDs
        do {
            let loaded = try await Product.products(for: requested)
            products = Dictionary(loaded.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        } catch {
            products = [:]
        }
    }

    func product(for option: DonationOption) -> Product? {
        products[option.productID]
    }

    enum PriceState: Equatable {
        case loading
        case available(displayPrice: String)
        case unavailable
    }

    func priceState(for option: DonationOption) -> PriceState {
        if let product = product(for: option) {
            return .available(displayPrice: product.displayPrice)
        }
        return didAttemptLoad && !isLoading ? .unavailable : .loading
    }

    func purchase(_ option: DonationOption) async {
        guard let product = product(for: option), purchasingProductID == nil else { return }
        purchasingProductID = product.id
        defer { purchasingProductID = nil }
        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                if case let .verified(transaction) = verification {
                    await transaction.finish()
                    showThankYou = true
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
