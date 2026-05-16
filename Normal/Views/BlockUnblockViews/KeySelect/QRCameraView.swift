import AVFoundation
import SwiftUI

struct QRCameraView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let scanResult: QRService.ScanResult

    func makeUIViewController(context _: Context) -> QRCameraController {
        let controller = QRCameraController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(_ controller: QRCameraController, context _: Context) {
        if scanResult == .none {
            controller.resumeScanning()
        }
    }
}

final class QRCameraController: UIViewController {
    var onScan: ((String) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "org.normalengineering.normal.qr.session")
    private let metadataQueue = DispatchQueue(label: "org.normalengineering.normal.qr.metadata")
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: session)
    private var isConfigured = false
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        sessionQueue.async { [weak self] in self?.configureSession() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startRunning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func resumeScanning() {
        hasScanned = false
        startRunning()
    }

    private func startRunning() {
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    private func configureSession() {
        guard !isConfigured,
              let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return }

        session.beginConfiguration()

        guard session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: metadataQueue)
        output.metadataObjectTypes = [.qr]

        session.commitConfiguration()

        isConfigured = true
        session.startRunning()
    }
}

extension QRCameraController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from _: AVCaptureConnection
    ) {
        guard !hasScanned,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue
        else { return }

        hasScanned = true
        sessionQueue.async { [weak self] in self?.session.stopRunning() }
        DispatchQueue.main.async { [weak self] in self?.onScan?(value) }
    }
}
