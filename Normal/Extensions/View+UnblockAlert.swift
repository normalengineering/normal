import SwiftUI

enum UnblockAlert {
    case failed(any Error)
    case mayEndLate

    init?(_ timing: UnblockTiming) {
        guard timing == .mayEndLate else { return nil }
        self = .mayEndLate
    }

    var title: LocalizedStringKey {
        switch self {
        case .failed: "Couldn't Unblock"
        case .mayEndLate: "Unblocked"
        }
    }

    var message: Text {
        switch self {
        case .failed(let error):
            Text(error.localizedDescription)
        case .mayEndLate:
            Text("iOS only tracks 20 schedules and timers at once, so this unblock may end up to 30 minutes late.")
        }
    }
}

extension View {
    func unblockAlert(_ alert: Binding<UnblockAlert?>) -> some View {
        self.alert(
            alert.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { alert.wrappedValue != nil },
                set: { if !$0 { alert.wrappedValue = nil } }
            ),
            presenting: alert.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { alert in
            alert.message
        }
    }
}
