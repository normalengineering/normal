import SwiftUI

struct FAQEntry: Identifiable {
    let id = UUID()
    let question: String
    let answer: AnyView
}
