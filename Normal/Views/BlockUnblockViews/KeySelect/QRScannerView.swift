import AVFoundation
import SwiftUI
import UIKit

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
                cameraScanner
            case .denied:
                deniedView
            }
        }
        .navigationTitle("Scan QR Code")
        .navigationBarTitleDisplayMode(.inline)
        .task { await permission.resolve() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await permission.resolve() } }
        }
    }

    private var cameraScanner: some View {
        ZStack {
            QRCameraRepresentable(
                onScan: { qrService.handleScan($0) },
                scanResult: qrService.scanResult
            )
            .ignoresSafeArea()

            resultOverlay
        }
    }

    private var deniedView: some View {
        ContentUnavailableView {
            Label("Camera Access Needed", systemImage: "camera.fill")
        } description: {
            Text("Normal needs camera access to scan QR code keys. Enable camera access for Normal in Settings.")
        } actions: {
            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var resultOverlay: some View {
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

private struct QRCameraRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let scanResult: QRService.ScanResult

    func makeUIViewController(context _: Context) -> QRCameraController {
        let controller = QRCameraController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(_ controller: QRCameraController, context _: Context) {
        if scanResult == .none {
            controller.resetForRescan()
        }
    }
}

final class QRCameraController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?

    private var captureSession: AVCaptureSession?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return }

        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)

        captureSession = session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let preview = view.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            preview.frame = view.bounds
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    func resetForRescan() {
        hasScanned = false
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession?.startRunning()
            }
        }
    }

    func metadataOutput(
        _: AVCaptureMetadataOutput,
        didOutput results: [AVMetadataObject],
        from _: AVCaptureConnection
    ) {
        guard !hasScanned,
              let readable = results.first as? AVMetadataMachineReadableCodeObject,
              let value = readable.stringValue
        else { return }

        hasScanned = true
        captureSession?.stopRunning()
        onScan?(value)
    }
}
