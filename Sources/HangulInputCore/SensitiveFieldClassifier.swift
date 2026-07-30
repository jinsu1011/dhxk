import Foundation

public enum SensitiveFieldClassifier {
    private static let phrases = [
        "username", "user name", "user-id", "user_id", "userid",
        "login", "log in", "sign in", "signin", "account",
        "email", "e-mail", "password", "passcode", "one-time",
        "verification code", "security code", "authentication code",
        "아이디", "로그인", "계정", "이메일", "비밀번호", "암호",
        "인증번호", "인증 번호", "보안 코드",
    ]
    private static let exactTokens: Set<String> = ["id", "otp", "pin"]

    public static func metadataSuggestsAuthentication(_ values: [String]) -> Bool {
        for value in values {
            let normalized = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
            if phrases.contains(where: { normalized.contains($0) }) { return true }
            let tokens = normalized.split { !$0.isLetter && !$0.isNumber }.map(String.init)
            if !exactTokens.isDisjoint(with: tokens) { return true }
        }
        return false
    }
}
