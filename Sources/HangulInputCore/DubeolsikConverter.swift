import Foundation

public enum DubeolsikConverter {
    private static let keyToJamo: [Character: Character] = [
        "r":"ㄱ", "R":"ㄲ", "s":"ㄴ", "e":"ㄷ", "E":"ㄸ", "f":"ㄹ",
        "a":"ㅁ", "q":"ㅂ", "Q":"ㅃ", "t":"ㅅ", "T":"ㅆ", "d":"ㅇ",
        "w":"ㅈ", "W":"ㅉ", "c":"ㅊ", "z":"ㅋ", "x":"ㅌ", "v":"ㅍ", "g":"ㅎ",
        "k":"ㅏ", "o":"ㅐ", "i":"ㅑ", "O":"ㅒ", "j":"ㅓ", "p":"ㅔ",
        "u":"ㅕ", "P":"ㅖ", "h":"ㅗ", "y":"ㅛ", "n":"ㅜ", "b":"ㅠ",
        "m":"ㅡ", "l":"ㅣ",
    ]
    private static let jamoToKeys: [Character: String] = [
        "ㄱ":"r", "ㄲ":"R", "ㄳ":"rt", "ㄴ":"s", "ㄵ":"sw", "ㄶ":"sg",
        "ㄷ":"e", "ㄸ":"E", "ㄹ":"f", "ㄺ":"fr", "ㄻ":"fa", "ㄼ":"fq",
        "ㄽ":"ft", "ㄾ":"fx", "ㄿ":"fv", "ㅀ":"fg", "ㅁ":"a", "ㅂ":"q",
        "ㅃ":"Q", "ㅄ":"qt", "ㅅ":"t", "ㅆ":"T", "ㅇ":"d", "ㅈ":"w",
        "ㅉ":"W", "ㅊ":"c", "ㅋ":"z", "ㅌ":"x", "ㅍ":"v", "ㅎ":"g",
        "ㅏ":"k", "ㅐ":"o", "ㅑ":"i", "ㅒ":"O", "ㅓ":"j", "ㅔ":"p",
        "ㅕ":"u", "ㅖ":"P", "ㅗ":"h", "ㅘ":"hk", "ㅙ":"ho", "ㅚ":"hl",
        "ㅛ":"y", "ㅜ":"n", "ㅝ":"nj", "ㅞ":"np", "ㅟ":"nl", "ㅠ":"b",
        "ㅡ":"m", "ㅢ":"ml", "ㅣ":"l",
    ]

    public static func englishKeysToHangul(_ keys: String) -> String {
        let capsLockLike = isAllUppercaseASCIIWord(keys)
        return HangulComposer.compose(keys.map { jamo(for: $0, capsLockLike: capsLockLike) ?? $0 })
    }

    public static func hangulToEnglishKeys(_ text: String) -> String {
        HangulComposer.decompose(text).map { jamoToKeys[$0] ?? String($0) }.joined()
    }

    public static func isConvertibleEnglish(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let capsLockLike = isAllUppercaseASCIIWord(text)
        return text.allSatisfy { jamo(for: $0, capsLockLike: capsLockLike) != nil }
    }

    /// 물리 Shift가 두벌식 의미를 바꾸는 Q/W/E/R/T/O/P는 혼합 대소문자에서
    /// 대문자 매핑을 유지한다. 나머지 알파벳 대문자는 같은 물리 키의 소문자와
    /// 동일하게 처리한다. 토큰 전체가 대문자면 Caps Lock 오입력으로 간주한다.
    private static func jamo(for key: Character, capsLockLike: Bool) -> Character? {
        let normalized = capsLockLike ? lowercaseASCII(key) : key
        if let exact = keyToJamo[normalized] { return exact }
        return keyToJamo[lowercaseASCII(normalized)]
    }

    private static func lowercaseASCII(_ key: Character) -> Character {
        guard key.isASCII, key.isLetter else { return key }
        return Character(String(key).lowercased())
    }

    private static func isAllUppercaseASCIIWord(_ text: String) -> Bool {
        let letters = text.filter { $0.isASCII && $0.isLetter }
        return !letters.isEmpty && letters.count == text.count && letters.allSatisfy { $0.isUppercase }
    }
}
