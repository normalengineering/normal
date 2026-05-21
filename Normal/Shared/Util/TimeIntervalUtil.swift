import Foundation

extension TimeInterval {
    static func days(_ count: Int) -> TimeInterval { TimeInterval(count) * 86_400 }
    static func hours(_ count: Int) -> TimeInterval { TimeInterval(count) * 3_600 }
    static func minutes(_ count: Int) -> TimeInterval { TimeInterval(count) * 60 }
}
