@testable import Normal

struct MockKeyMethod: KeyMethod {
    let result: KeyResult

    func checkKey() async -> KeyResult { result }
}
