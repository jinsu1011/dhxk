import Foundation

public enum ReplacementTokenValidator {
    public static func exactDisplayedToken(
        rawKeys: String,
        displayedToken: String?,
        direction: InputDirection
    ) -> String? {
        guard let displayedToken, !displayedToken.isEmpty else { return nil }
        let expected: String
        switch direction {
        case .englishToKorean:
            expected = rawKeys
        case .koreanToEnglish:
            expected = DubeolsikConverter.englishKeysToHangul(rawKeys)
        }
        return displayedToken == expected ? displayedToken : nil
    }
}
