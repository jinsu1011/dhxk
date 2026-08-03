import Foundation

public enum CompatibilityAppClassifier {
    private static let supportedBundleIDs: Set<String> = [
        "com.openai.codex", "com.openai.chat",
        "com.anthropic.claudefordesktop", "com.anthropic.claude",
        "com.google.antigravity",
        "com.kakao.KakaoTalkMac", "notion.id",
        "com.google.Chrome", "com.apple.Safari",
        "com.apple.TextEdit", "com.apple.Notes",
        "com.apple.Pages", "com.apple.iWork.Pages",
        "com.microsoft.Word", "com.tinyspeck.slackmacgap", "com.hnc.Hanword",
    ]
    private static let chromiumAccessibilityBundleIDs: Set<String> = [
        "com.openai.codex", "com.openai.chat",
        "com.anthropic.claudefordesktop", "com.anthropic.claude",
        "com.google.antigravity", "notion.id",
        "com.tinyspeck.slackmacgap",
    ]
    private static let enhancedAccessibilityBundleIDs: Set<String> = [
        "com.google.Chrome",
    ]
    private static let syntheticReplacementBundleIDs = enhancedAccessibilityBundleIDs

    public static func supportsFallback(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return supportedBundleIDs.contains(bundleIdentifier)
    }

    public static func requiresManualAccessibility(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return chromiumAccessibilityBundleIDs.contains(bundleIdentifier)
    }

    public static func requiresEnhancedAccessibility(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return enhancedAccessibilityBundleIDs.contains(bundleIdentifier)
    }

    public static func prefersSyntheticReplacement(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return syntheticReplacementBundleIDs.contains(bundleIdentifier)
    }

    public static func prefersPasteReplacement(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return chromiumAccessibilityBundleIDs.contains(bundleIdentifier)
    }
}
