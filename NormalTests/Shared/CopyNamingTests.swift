@testable import Normal
import Testing

struct CopyNamingTests {
    @Test func appendsCopyWhenNameIsFree() {
        #expect(CopyNaming.name(for: "Work", existing: ["Work"]) == "Work Copy")
    }

    @Test func numbersCopyWhenCopyIsTaken() {
        #expect(CopyNaming.name(for: "Work", existing: ["Work", "Work Copy"]) == "Work Copy 2")
    }

    @Test func skipsTakenNumbers() {
        let existing = ["Work", "Work Copy", "Work Copy 2"]
        #expect(CopyNaming.name(for: "Work", existing: existing) == "Work Copy 3")
    }

    @Test func similarNamesDoNotCountAsTaken() {
        let existing = ["Work", "work copy", "Work Copy 2", "Workout Copy"]
        #expect(CopyNaming.name(for: "Work", existing: existing) == "Work Copy")
    }
}
