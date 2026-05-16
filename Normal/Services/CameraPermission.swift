import AVFoundation
import Observation

enum CameraAccess: Equatable {
    case checking
    case authorized
    case denied
}

protocol CameraAuthorizing {
    func authorizationStatus() -> AVAuthorizationStatus
    func requestAccess() async -> Bool
}

struct AVCameraAuthorizer: CameraAuthorizing {
    func authorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}

@Observable
final class CameraPermissionModel {
    private(set) var access: CameraAccess = .checking
    private let authorizer: any CameraAuthorizing

    init(authorizer: any CameraAuthorizing = AVCameraAuthorizer()) {
        self.authorizer = authorizer
    }

    @MainActor
    func resolve() async {
        switch authorizer.authorizationStatus() {
        case .authorized:
            access = .authorized
        case .notDetermined:
            access = await authorizer.requestAccess() ? .authorized : .denied
        default:
            access = .denied
        }
    }
}
