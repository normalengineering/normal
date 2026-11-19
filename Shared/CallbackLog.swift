import Foundation

nonisolated enum CallbackLog {
    static let maxEntries = 1000

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.appGroupID)?
            .appending(path: "callbackLog.txt")
    }

    static func record(_ message: @autoclosure () -> String, at date: Date = .now) {
        #if DEBUG
            guard let fileURL else { return }
            let timestamp = Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .current).format(date)
            let lines = read() + ["\(timestamp) \(message())"]
            try? lines.suffix(maxEntries)
                .joined(separator: "\n")
                .write(to: fileURL, atomically: true, encoding: .utf8)
        #endif
    }

    static func read() -> [String] {
        guard let fileURL,
            let text = try? String(contentsOf: fileURL, encoding: .utf8)
        else { return [] }
        return text.split(separator: "\n").map(String.init)
    }

    static func clear() {
        guard let fileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}
