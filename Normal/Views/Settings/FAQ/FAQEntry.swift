import SwiftUI

struct FAQEntry: Identifiable {
    let id = UUID()
    let question: String
    let answer: AnyView
}

struct FAQSection: Identifiable {
    let id = UUID()
    let title: String
    let entries: [FAQEntry]
}
