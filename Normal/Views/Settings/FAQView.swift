import SwiftUI

struct FAQView: View {
    var body: some View {
        List {
            ForEach(FAQContent.sections) { section in
                Section(section.title) {
                    ForEach(section.entries) { entry in
                        FAQItem(question: entry.question, answer: entry.answer)
                    }
                }
            }
        }
    }
}
