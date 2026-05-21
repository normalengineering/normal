import Foundation

extension TimeInterval {
    static func days(_ count: Int) -> TimeInterval { TimeInterval(count) * 86400 }
    static func hours(_ count: Int) -> TimeInterval { TimeInterval(count) * 3600 }
    static func minutes(_ count: Int) -> TimeInterval { TimeInterval(count) * 60 }
}
