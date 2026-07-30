import AppKit
import HangulInputCore

final class SystemLexicon {
    private let checker = NSSpellChecker.shared
    private var cache: [String: Bool] = [:]
    private let cacheLimit = 512

    func evidence(
        original: String,
        replacement: String,
        direction: InputDirection,
        learnedInSession: Bool
    ) -> LexicalEvidence {
        let originalLanguage = direction == .englishToKorean ? "en" : "ko"
        let replacementLanguage = direction == .englishToKorean ? "ko" : "en"
        return LexicalEvidence(
            originalKnown: isKnown(original, language: originalLanguage),
            replacementKnown: isKnown(replacement, language: replacementLanguage),
            learnedInSession: learnedInSession
        )
    }

    private func isKnown(_ word: String, language: String) -> Bool {
        guard word.count >= 2 else { return false }
        let key = "\(language):\(word.lowercased())"
        if let cached = cache[key] { return cached }
        var wordCount = 0
        let misspelled = checker.checkSpelling(
            of: word,
            startingAt: 0,
            language: language,
            wrap: false,
            inSpellDocumentWithTag: 0,
            wordCount: &wordCount
        )
        let known = misspelled.location == NSNotFound
        if cache.count >= cacheLimit { cache.removeAll(keepingCapacity: true) }
        cache[key] = known
        return known
    }
}
