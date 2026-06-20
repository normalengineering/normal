import StoreKit
import SwiftUI

struct DonationView: View {
    @Environment(DonationService.self) private var donationService
    @State private var cadence: DonationCadence = .oneTime

    private let columns = [GridItem(.adaptive(minimum: 86), spacing: DS.Spacing.md)]

    var body: some View {
        @Bindable var donationService = donationService

        List {
            Section {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Image(systemName: "heart.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.pink)
                    Text("Support Normal")
                        .font(.title2.bold())
                    Text("Normal is free and open-source, and always will be. No paywalls, subscriptions, ads or data-collection. If you would like to support Normal, donations are greatly appreciated.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, DS.Spacing.sm)
            }

            Section {
                Picker("Frequency", selection: $cadence) {
                    ForEach(DonationCadence.allCases) { cadence in
                        Text(cadence.title).tag(cadence)
                    }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)

                LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
                    ForEach(DonationCatalog.options(for: cadence)) { option in
                        amountButton(option)
                    }
                }
                .padding(.vertical, DS.Spacing.xs)
                .listRowSeparator(.hidden)
            } header: {
                Text(cadence == .monthly ? "Monthly support" : "One-time tip")
            } footer: {
                Text("Completely optional, thank you for even considering it. 💛")
            }
        }
        .task { await donationService.loadProducts() }
        .alert("Thank you for your donation! 💛", isPresented: $donationService.showThankYou) {
            Button("You're welcome", role: .cancel) {}
        } message: {
            Text("Your support means the world and goes straight into Normal's development.")
        }
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(donationService.errorMessage ?? "")
        }
    }

    private func amountButton(_ option: DonationOption) -> some View {
        let state = donationService.priceState(for: option)
        let isPurchasing = donationService.purchasingProductID == option.productID

        return Button {
            Task { await donationService.purchase(option) }
        } label: {
            VStack(spacing: 2) {
                priceLabel(for: state)
                Text(option.cadence == .monthly ? "per month" : "once")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(
                .pink.opacity(DS.Opacity.muted),
                in: RoundedRectangle(cornerRadius: DS.Radius.md)
            )
            .overlay {
                if isPurchasing {
                    ProgressView()
                }
            }
            .opacity(state == .unavailable ? DS.Opacity.muted : 1)
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.pink)
        .disabled(!isPurchasable(state))
        .accessibilityIdentifier("donation.\(option.cadence.slug).\(option.amount)")
        .accessibilityLabel(accessibilityLabel(for: option, state: state))
    }

    private func isPurchasable(_ state: DonationService.PriceState) -> Bool {
        guard donationService.purchasingProductID == nil else { return false }
        if case .available = state { return true }
        return false
    }

    @ViewBuilder
    private func priceLabel(for state: DonationService.PriceState) -> some View {
        switch state {
        case .loading:
            Text(verbatim: "$00")
                .font(.headline)
                .monospacedDigit()
                .redacted(reason: .placeholder)
        case let .available(displayPrice):
            Text(displayPrice)
                .font(.headline)
                .monospacedDigit()
        case .unavailable:
            Text(verbatim: "—")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private func accessibilityLabel(for option: DonationOption, state: DonationService.PriceState) -> String {
        let cadence = option.cadence == .monthly ? "per month" : "one-time"
        switch state {
        case .loading: return "Loading price, \(cadence)"
        case let .available(displayPrice): return "\(displayPrice) \(cadence)"
        case .unavailable: return "Currently unavailable, \(cadence)"
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { donationService.errorMessage != nil },
            set: { if !$0 { donationService.errorMessage = nil } }
        )
    }
}
