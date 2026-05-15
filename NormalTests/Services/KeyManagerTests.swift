@testable import Normal
import Testing

@MainActor
struct KeyManagerTests {
    @Test func successInvokesAction() async {
        let manager = KeyManager()
        var didRun = false
        let result = await manager.performWithKeyCheck(using: FakeKeyMethod(result: .success)) {
            didRun = true
        }
        #expect(result)
        #expect(didRun)
    }

    @Test func failureDoesNotInvokeAction() async {
        let manager = KeyManager()
        var didRun = false
        let result = await manager.performWithKeyCheck(using: FakeKeyMethod(result: .failure)) {
            didRun = true
        }
        #expect(!result)
        #expect(!didRun)
    }

    @Test func cancellationDoesNotInvokeAction() async {
        let manager = KeyManager()
        var didRun = false
        let result = await manager.performWithKeyCheck(using: FakeKeyMethod(result: .cancelled)) {
            didRun = true
        }
        #expect(!result)
        #expect(!didRun)
    }
}
