import Foundation
@testable import Normal
import Testing

struct WidgetDeepLinkTests {
    private func queryItems(_ url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.compactMap { item in
            item.value.map { (item.name, $0) }
        })
    }

    @Test func buildsSchemeAndHost() {
        let url = WidgetDeepLink.unlockURL(groupID: UUID(), durationSeconds: nil, keyTypeRawValue: nil)
        #expect(url.scheme == WidgetDeepLink.scheme)
        #expect(url.host == WidgetDeepLink.unlockHost)
    }

    @Test func includesAllParamsWhenProvided() {
        let id = UUID()
        let url = WidgetDeepLink.unlockURL(groupID: id, durationSeconds: 3600, keyTypeRawValue: "QR")
        let items = queryItems(url)
        #expect(items[WidgetDeepLink.groupQueryItem] == id.uuidString)
        #expect(items[WidgetDeepLink.durationQueryItem] == "3600")
        #expect(items[WidgetDeepLink.keyQueryItem] == "QR")
    }

    @Test func omitsNilParams() {
        let url = WidgetDeepLink.unlockURL(groupID: UUID(), durationSeconds: nil, keyTypeRawValue: nil)
        let items = queryItems(url)
        #expect(items[WidgetDeepLink.durationQueryItem] == nil)
        #expect(items[WidgetDeepLink.keyQueryItem] == nil)
        #expect(items[WidgetDeepLink.groupQueryItem] != nil)
    }

    @Test func blockURLUsesBlockHostWithOnlyGroup() {
        let id = UUID()
        let url = WidgetDeepLink.blockURL(groupID: id)
        #expect(url.scheme == WidgetDeepLink.scheme)
        #expect(url.host == WidgetDeepLink.blockHost)
        let items = queryItems(url)
        #expect(items[WidgetDeepLink.groupQueryItem] == id.uuidString)
        #expect(items[WidgetDeepLink.durationQueryItem] == nil)
        #expect(items[WidgetDeepLink.keyQueryItem] == nil)
    }
}
