import SwiftUI

struct FAQView: View {
    var body: some View {
        List {
            ForEach(FAQContent.entries) { entry in
                FAQItem(question: entry.question, answer: entry.answer)
            }
        }
    }
}
