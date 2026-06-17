import FamilyControls
import Foundation
@testable import Normal
import SwiftData
import Testing

@MainActor
struct KeyMigrationTests {
    private static let models: [any PersistentModel.Type] = [
        Key.self, Settings.self, BlockSchedule.self, SelectedApps.self, AppGroup.self,
    ]

    private func storeURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("keymig-\(UUID().uuidString).store")
    }

    private func removeStore(at url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(
                at: url.deletingLastPathComponent()
                    .appendingPathComponent(url.lastPathComponent + suffix)
            )
        }
    }

    private func makeContainer(at url: URL) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(Self.models),
            configurations: ModelConfiguration(schema: Schema(Self.models), url: url)
        )
    }

    @Test func keyWrittenWithoutScanKindReopensAndBehavesAsQRCode() throws {
        let url = storeURL()
        defer { removeStore(at: url) }

        do {
            let container = try makeContainer(at: url)
            let key = Key(name: "Legacy", type: .qr, rawValue: "old-secret")
            container.mainContext.insert(key)
            try container.mainContext.save()
        }

        let reopened = try makeContainer(at: url)
        let keys = try reopened.mainContext.fetch(FetchDescriptor<Key>())

        #expect(keys.count == 1)
        let key = try #require(keys.first)
        #expect(key.scanKind == nil)
        #expect(key.displayTypeLabel == "QR Code")
        #expect(key.matches(unhashedId: "old-secret"))
        #expect(!key.matches(unhashedId: "wrong"))
    }

    @Test func scanKindSurvivesAStoreReopen() throws {
        let url = storeURL()
        defer { removeStore(at: url) }

        do {
            let container = try makeContainer(at: url)
            container.mainContext.insert(
                Key(name: "Gym", type: .qr, rawValue: "v", scanKind: .barcode)
            )
            try container.mainContext.save()
        }

        let reopened = try makeContainer(at: url)
        let key = try #require(try reopened.mainContext.fetch(FetchDescriptor<Key>()).first)

        #expect(key.scanKind == .barcode)
        #expect(key.displayTypeLabel == "Barcode")
    }

    @Test func sortIndexDefaultsAndPersistsAcrossReopen() throws {
        let url = storeURL()
        defer { removeStore(at: url) }

        do {
            let container = try makeContainer(at: url)
            container.mainContext.insert(Key(name: "Legacy", type: .qr, rawValue: "a"))
            container.mainContext.insert(Key(name: "Ordered", type: .nfc, rawValue: "b", sortIndex: 5))
            try container.mainContext.save()
        }

        let reopened = try makeContainer(at: url)
        let byName = try reopened.mainContext.fetch(FetchDescriptor<Key>())
            .reduce(into: [String: Key]()) { $0[$1.name] = $1 }

        #expect(byName["Legacy"]?.sortIndex == 0)
        #expect(byName["Ordered"]?.sortIndex == 5)
    }

    @Test func groupIDDefaultsNilAndPersistsAcrossReopen() throws {
        let url = storeURL()
        defer { removeStore(at: url) }

        let groupA = UUID()
        do {
            let container = try makeContainer(at: url)
            container.mainContext.insert(Key(name: "Legacy", type: .qr, rawValue: "a"))
            container.mainContext.insert(Key(name: "Grouped", type: .nfc, rawValue: "b", groupID: groupA))
            try container.mainContext.save()
        }

        let reopened = try makeContainer(at: url)
        let byName = try reopened.mainContext.fetch(FetchDescriptor<Key>())
            .reduce(into: [String: Key]()) { $0[$1.name] = $1 }

        #expect(byName["Legacy"]?.groupID == nil)
        #expect(byName["Grouped"]?.groupID == groupA)
    }

    @Test func mixedLegacyAndNewKeysCoexistAfterReopen() throws {
        let url = storeURL()
        defer { removeStore(at: url) }

        do {
            let container = try makeContainer(at: url)
            container.mainContext.insert(Key(name: "Legacy", type: .qr, rawValue: "a"))
            container.mainContext.insert(Key(name: "Tag", type: .nfc, rawValue: "b"))
            container.mainContext.insert(
                Key(name: "New", type: .qr, rawValue: "c", scanKind: .qr)
            )
            try container.mainContext.save()
        }

        let reopened = try makeContainer(at: url)
        let byName = try reopened.mainContext.fetch(FetchDescriptor<Key>())
            .reduce(into: [String: Key]()) { $0[$1.name] = $1 }

        #expect(byName["Legacy"]?.displayTypeLabel == "QR Code")
        #expect(byName["Tag"]?.displayTypeLabel == "NFC Tag")
        #expect(byName["New"]?.displayTypeLabel == "QR Code")
        #expect(byName["Legacy"]?.matches(unhashedId: "a") == true)
        #expect(byName["Tag"]?.matches(unhashedId: "b") == true)
    }
}
