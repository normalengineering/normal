import AVFoundation
@testable import Normal
import Testing

@MainActor
struct CameraPermissionTests {
    @Test func startsInCheckingState() {
        let model = CameraPermissionModel(authorizer: FakeCameraAuthorizer())
        #expect(model.access == .checking)
    }

    @Test func authorizedStaysAuthorizedWithoutPrompting() async {
        let authorizer = FakeCameraAuthorizer(status: .authorized)
        let model = CameraPermissionModel(authorizer: authorizer)

        await model.resolve()

        #expect(model.access == .authorized)
        #expect(authorizer.requestCount == 0)
    }

    @Test func notDeterminedGrantedBecomesAuthorized() async {
        let authorizer = FakeCameraAuthorizer(status: .notDetermined, grantOnRequest: true)
        let model = CameraPermissionModel(authorizer: authorizer)

        await model.resolve()

        #expect(model.access == .authorized)
        #expect(authorizer.requestCount == 1)
    }

    @Test func notDeterminedDeniedBecomesDenied() async {
        let authorizer = FakeCameraAuthorizer(status: .notDetermined, grantOnRequest: false)
        let model = CameraPermissionModel(authorizer: authorizer)

        await model.resolve()

        #expect(model.access == .denied)
        #expect(authorizer.requestCount == 1)
    }

    @Test func deniedStaysDeniedWithoutPrompting() async {
        let authorizer = FakeCameraAuthorizer(status: .denied)
        let model = CameraPermissionModel(authorizer: authorizer)

        await model.resolve()

        #expect(model.access == .denied)
        #expect(authorizer.requestCount == 0)
    }

    @Test func restrictedBecomesDenied() async {
        let authorizer = FakeCameraAuthorizer(status: .restricted)
        let model = CameraPermissionModel(authorizer: authorizer)

        await model.resolve()

        #expect(model.access == .denied)
        #expect(authorizer.requestCount == 0)
    }
}
