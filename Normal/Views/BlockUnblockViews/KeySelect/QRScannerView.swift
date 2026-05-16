import SwiftUI

struct QRScannerView: View {
    let qrService: QRService

    @Environment(\.scenePhase) private var scenePhase
    @State private var permission = CameraPermissionModel()

    var body: some View {
        ZStack {
            switch permission.access {
            case .checking:
                ProgressView()
            case .authorized:
                scanner
            case .denied:
                CameraAccessDeniedView()
            }
        }
        .navigationTitle("Scan QR Code")
        .navigationBarTitleDisplayMode(.inline)
        .task { await permission.resolve() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await permission.resolve() }
            }
        }
    }

    private var scanner: some View {
        ZStack {
            QRCameraView(onScan: qrService.handleScan, scanResult: qrService.scanResult)
                .ignoresSafeArea()
            QRScanOverlay(scanResult: qrService.scanResult)
            scanResultBadge
        }
    }

    @ViewBuilder
    private var scanResultBadge: some View {
        switch qrService.scanResult {
        case .none:
            EmptyView()
        case .valid:
            ScanResultBadge(systemImage: "checkmark.circle.fill", tint: .green, text: "Key Verified")
        case .invalid:
            ScanResultBadge(systemImage: "xmark.circle.fill", tint: .red, text: "Invalid Key")
        }
    }
}
