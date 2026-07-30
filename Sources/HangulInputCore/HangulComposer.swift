import Foundation

public enum HangulComposer {
    private static let initials = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
    private static let vowels = Array("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ")
    private static let finals = Array(" ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ")

    private static let compoundVowels: [String: Character] = [
        "ㅗㅏ": "ㅘ", "ㅗㅐ": "ㅙ", "ㅗㅣ": "ㅚ",
        "ㅜㅓ": "ㅝ", "ㅜㅔ": "ㅞ", "ㅜㅣ": "ㅟ", "ㅡㅣ": "ㅢ",
    ]
    private static let compoundFinals: [String: Character] = [
        "ㄱㅅ": "ㄳ", "ㄴㅈ": "ㄵ", "ㄴㅎ": "ㄶ", "ㄹㄱ": "ㄺ",
        "ㄹㅁ": "ㄻ", "ㄹㅂ": "ㄼ", "ㄹㅅ": "ㄽ", "ㄹㅌ": "ㄾ",
        "ㄹㅍ": "ㄿ", "ㄹㅎ": "ㅀ", "ㅂㅅ": "ㅄ",
    ]
    private static let splitFinals: [Character: (Character, Character)] = {
        Dictionary(uniqueKeysWithValues: compoundFinals.map { ($0.value, (Array($0.key)[0], Array($0.key)[1])) })
    }()

    public static func compose(_ jamo: [Character]) -> String {
        var output = ""
        var initial: Character?
        var vowel: Character?
        var final: Character?

        func syllable(_ l: Character?, _ v: Character?, _ t: Character?) -> String {
            guard let l, let v,
                  let li = initials.firstIndex(of: l),
                  let vi = vowels.firstIndex(of: v) else {
                return [l, v, t].compactMap { $0 }.map(String.init).joined()
            }
            let ti = t.flatMap { finals.firstIndex(of: $0) } ?? 0
            return String(UnicodeScalar(0xAC00 + (li * 21 + vi) * 28 + ti)!)
        }

        func flush() {
            output += syllable(initial, vowel, final)
            initial = nil; vowel = nil; final = nil
        }

        for current in jamo {
            if vowels.contains(current) {
                if initial == nil {
                    output.append(current)
                } else if vowel == nil {
                    vowel = current
                } else if final == nil {
                    let pair = String([vowel!, current])
                    if let combined = compoundVowels[pair] {
                        vowel = combined
                    } else {
                        flush()
                        output.append(current)
                    }
                } else {
                    let oldFinal = final!
                    if let (first, second) = splitFinals[oldFinal] {
                        final = first
                        output += syllable(initial, vowel, final)
                        initial = second; vowel = current; final = nil
                    } else if initials.contains(oldFinal) {
                        final = nil
                        output += syllable(initial, vowel, nil)
                        initial = oldFinal; vowel = current
                    } else {
                        flush()
                        output.append(current)
                    }
                }
            } else if initials.contains(current) {
                if initial == nil {
                    initial = current
                } else if vowel == nil {
                    flush()
                    initial = current
                } else if final == nil, finals.contains(current) {
                    final = current
                } else if let existing = final,
                          let combined = compoundFinals[String([existing, current])] {
                    final = combined
                } else {
                    flush()
                    initial = current
                }
            } else {
                flush()
                output.append(current)
            }
        }
        flush()
        return output
    }

    public static func decompose(_ text: String) -> [Character] {
        var result: [Character] = []
        for scalar in text.unicodeScalars {
            let value = Int(scalar.value)
            guard (0xAC00...0xD7A3).contains(value) else {
                result.append(Character(String(scalar)))
                continue
            }
            let offset = value - 0xAC00
            let l = offset / (21 * 28)
            let v = (offset % (21 * 28)) / 28
            let t = offset % 28
            result.append(initials[l])
            result.append(vowels[v])
            if t > 0 { result.append(finals[t]) }
        }
        return result
    }
}
