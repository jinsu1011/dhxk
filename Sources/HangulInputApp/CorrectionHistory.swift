import ApplicationServices
import Foundation

struct CorrectionRecord {
    let element: AXUIElement
    let range: CFRange
    let originalWithDelimiter: String
    let replacementWithDelimiter: String
}

final class CorrectionHistory {
    private(set) var last: CorrectionRecord?
    private var rejected = Set<String>()
    private var accepted = Set<String>()
    private let learnedTokenLimit = 512

    func record(_ item: CorrectionRecord) { last = item }
    func clear() { last = nil }
    func accept(_ original: String) {
        if accepted.count >= learnedTokenLimit { accepted.removeAll(keepingCapacity: true) }
        accepted.insert(original)
        rejected.remove(original)
    }
    func reject(_ original: String) {
        if rejected.count >= learnedTokenLimit { rejected.removeAll(keepingCapacity: true) }
        rejected.insert(original)
        accepted.remove(original)
    }
    func wasRejected(_ original: String) -> Bool { rejected.contains(original) }
    func wasAccepted(_ original: String) -> Bool { accepted.contains(original) }
}
