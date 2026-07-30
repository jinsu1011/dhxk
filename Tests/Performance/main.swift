import Dispatch
import Foundation
import HangulInputCore

let iterations = CommandLine.arguments.dropFirst().first.flatMap(Int.init) ?? 250_000
let engine = CorrectionEngine()
let samples: [(String, InputDirection)] = [
    ("dkssudgktpdy", .englishToKorean),
    ("rlawlstn", .englishToKorean),
    ("performance", .englishToKorean),
    (DubeolsikConverter.englishKeysToHangul("hello"), .koreanToEnglish),
    (DubeolsikConverter.englishKeysToHangul("implementation"), .koreanToEnglish),
    (DubeolsikConverter.englishKeysToHangul("running"), .koreanToEnglish),
]

var checksum = 0
let start = DispatchTime.now().uptimeNanoseconds
for index in 0..<iterations {
    let sample = samples[index % samples.count]
    if let decision = engine.evaluate(sample.0, direction: sample.1) {
        checksum &+= decision.replacement.utf8.count
        checksum &+= decision.shouldAutoCorrect ? 1 : 0
    }
}
let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000
let rate = Double(iterations) / elapsed
print(String(format: "BENCHMARK iterations=%d elapsed=%.4fs rate=%.0f/s checksum=%d", iterations, elapsed, rate, checksum))
