@testable import Normal
import Testing

@MainActor
struct QRServiceTests {
    private func waitUntilScanning(_ service: QRService) async {
        while !service.isScanning {
            await Task.yield()
        }
    }

    @Test func validScanCompletesAfterTheBadge() async throws {
        let service = QRService()
        let scan = Task { try await service.scan { $0 == "code" } }
        await waitUntilScanning(service)

        service.handleScan("code", kind: .qr)

        #expect(try await scan.value == "code")
        #expect(!service.isScanning)
    }

    @Test func validatedCodeDoesNotCompleteALaterScan() async throws {
        let service = QRService()
        let first = Task { try await service.scan { $0 == "group-code" } }
        await waitUntilScanning(service)
        service.handleScan("group-code", kind: .qr)
        service.cancel()

        let second = Task { try await service.scan { $0 == "global-code" } }
        await waitUntilScanning(service)
        try await Task.sleep(for: .seconds(1.5))

        #expect(service.isScanning)
        service.cancel()
        await #expect(throws: ScanError.self) { try await first.value }
        await #expect(throws: ScanError.self) { try await second.value }
    }
}
