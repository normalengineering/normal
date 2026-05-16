import AVFoundation
@testable import Normal

final class FakeCameraAuthorizer: CameraAuthorizing {
    var status: AVAuthorizationStatus
    var grantOnRequest: Bool
    private(set) var requestCount = 0

    init(status: AVAuthorizationStatus = .notDetermined, grantOnRequest: Bool = true) {
        self.status = status
        self.grantOnRequest = grantOnRequest
    }

    func authorizationStatus() -> AVAuthorizationStatus { status }

    func requestAccess() async -> Bool {
        requestCount += 1
        return grantOnRequest
    }
}
