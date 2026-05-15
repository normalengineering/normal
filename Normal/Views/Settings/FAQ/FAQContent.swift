import SwiftUI

enum FAQContent {
    static let entries: [FAQEntry] = [
        FAQEntry(question: "Is Normal really free?", answer: FAQAnswer.isNormalFree),
        FAQEntry(question: "Is it really privacy friendly?", answer: FAQAnswer.privacyFriendly),
        FAQEntry(question: "How does Normal fix bugs and improve without data collection?", answer: FAQAnswer.bugsWithoutCollection),
        FAQEntry(question: "Does Normal work without an internet connection?", answer: FAQAnswer.worksOffline),
        FAQEntry(question: "How is Normal different from Apple's built-in Screen Time?", answer: FAQAnswer.vsAppleScreenTime),
        FAQEntry(question: "How is Normal different from the other screen time apps?", answer: FAQAnswer.vsOtherApps),
        FAQEntry(question: "Can I contribute to the project?", answer: FAQAnswer.contribute),
        FAQEntry(question: "Can I use Normal to make my iPhone a dumbphone or semi-dumb feature phone?", answer: FAQAnswer.dumbphone),
        FAQEntry(question: "Why do I have to reselect apps in my schedules and groups when I update my selected apps?", answer: FAQAnswer.reselectAppLimitation),
        FAQEntry(question: "Can I prevent disabling Normal via Settings? I want to make it impossible to access blocked apps.", answer: FAQAnswer.settingsBypass),
    ]
}
