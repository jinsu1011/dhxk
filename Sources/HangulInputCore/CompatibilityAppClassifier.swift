import Foundation

public enum CompatibilityAppClassifier {
    private static let supportedBundleIDs: Set<String> = [
        "com.openai.codex", "com.openai.chat",
        "com.anthropic.claudefordesktop", "com.anthropic.claude",
        "com.kakao.KakaoTalkMac", "notion.id",
        "com.google.Chrome", "com.apple.Safari",
        "com.apple.TextEdit", "com.apple.Notes",
        "com.apple.Pages", "com.apple.iWork.Pages",
        "com.microsoft.Word", "com.tinyspeck.slackmacgap", "com.hnc.Hanword",
    ]

    public static func supportsFallback(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return supportedBundleIDs.contains(bundleIdentifier)
    }
}
