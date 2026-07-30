import Foundation

final class TestSuite {
    private(set) var checks = 0
    private(set) var failures = 0

    func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
        checks += 1
        if condition() {
            print("PASS: \(name)")
        } else {
            failures += 1
            print("FAIL: \(name)")
        }
    }
}

let suite = TestSuite()
runConverterTests(suite)
runCorrectionEngineTests(suite)
runPilotRegistrationTests(suite)
print("RESULT: \(suite.checks - suite.failures)/\(suite.checks) checks passed")
if suite.failures > 0 { exit(EXIT_FAILURE) }
