@testable import Normal
import Testing

struct KeyManagerTests {
    @Test @MainActor func performWithKeyCheckSuccessCallsAction() async {
        let manager = KeyManager()
        var actionCalled = false

        let result = await manager.performWithKeyCheck(
            using: MockKeyMethod(result: .success),
            action: { actionCalled = true }
        )

        #expect(result == true)
        #expect(actionCalled)
    }

    @Test @MainActor func performWithKeyCheckFailureDoesNotCallAction() async {
        let manager = KeyManager()
        var actionCalled = false

        let result = await manager.performWithKeyCheck(
            using: MockKeyMethod(result: .failure),
            action: { actionCalled = true }
        )

        #expect(result == false)
        #expect(!actionCalled)
    }

    @Test @MainActor func performWithKeyCheckCancelledDoesNotCallAction() async {
        let manager = KeyManager()
        var actionCalled = false

        let result = await manager.performWithKeyCheck(
            using: MockKeyMethod(result: .cancelled),
            action: { actionCalled = true }
        )

        #expect(result == false)
        #expect(!actionCalled)
    }
}
