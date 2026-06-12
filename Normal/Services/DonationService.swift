import Foundation
import StoreKit

@MainActor
@Observable
final class DonationService {
    private(set) var products: [String: Product] = [:]
    private(set) var isLoading = false
    private(set) var purchasingProductID: String?
    var showThankYou = false
    var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    var hasLoadedProducts: Bool { !products.isEmpty }

    init() {
        updatesTask = Task {
            for await update in Transaction.updates {
                guard case let .verified(transaction) = update else { continue }
                await transaction.finish()
            }
        }
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: DonationCatalog.allProductIDs)
            products = Dictionary(loaded.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        } catch {
            products = [:]
        }
    }

    func product(for option: DonationOption) -> Product? {
        products[option.productID]
    }

    func displayPrice(for option: DonationOption) -> String {
        product(for: option)?.displayPrice ?? option.displayAmount
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
