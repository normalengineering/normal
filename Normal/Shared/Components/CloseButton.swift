import SwiftUI

struct CloseButton: View {
    enum Placement {
        case toolbar
        case inline
    }

    var placement: Placement = .toolbar
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            switch placement {
            case .toolbar:
                Button(role: .close, action: action)
            case .inline:
                Button(role: .close, action: action) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .accessibilityLabel("Close")
            }
        } else {
            Button(action: action) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(placement == .toolbar ? .hierarchical : .monochrome)
                    .foregroundStyle(placement == .toolbar ? .secondary : .tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }
}
