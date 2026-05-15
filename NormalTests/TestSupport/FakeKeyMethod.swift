@testable import Normal

struct FakeKeyMethod: KeyMethod {
    let result: KeyResult
    func checkKey() async -> KeyResult { result }
}
