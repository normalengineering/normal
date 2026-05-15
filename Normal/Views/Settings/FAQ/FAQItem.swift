import SwiftUI

struct FAQItem: View {
    let question: String
    let answer: AnyView
    @State private var isExpanded = false

    var body: some View {
        ExpandableSection(title: LocalizedStringKey(question), isExpanded: $isExpanded) {
            answer
        }
    }
}
