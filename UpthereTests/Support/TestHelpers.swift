import Foundation

func makeIsolatedDefaults() -> (UserDefaults, String) {
    let suiteName = "test.suite.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        fatalError("Failed to initialize UserDefaults suite for: \(suiteName)")
    }
    return (defaults, suiteName)
}
