import AppKit
import Carbon
import ApplicationServices
import HangulInputCore

enum SecurityGuard {
    private static let defaultExcludedBundleIDs: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "com.microsoft.VSCode",
        "com.apple.dt.Xcode", "com.jetbrains.intellij", "com.jetbrains.CLion",
        "com.microsoft.rdc.macos", "com.teamviewer.TeamViewer",
    ]

    static var isSecureInputEnabled: Bool { IsSecureEventInputEnabled() }

    static var isExcludedFrontmostApp: Bool {
        guard let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return true }
        let userExcluded = Set(UserDefaults.standard.stringArray(forKey: "ExcludedBundleIDs") ?? [])
        return defaultExcludedBundleIDs.contains(id) || userExcluded.contains(id) ||
            id.hasPrefix("com.jetbrains.") || id == Bundle.main.bundleIdentifier
    }

    static func isSafeTextElement(_ element: AXUIElement) -> Bool {
        var roleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue) == .success,
              let role = roleValue as? String,
              [kAXTextFieldRole as String, kAXTextAreaRole as String, kAXComboBoxRole as String].contains(role)
        else { return false }

        var subroleValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleValue) == .success,
           let subrole = subroleValue as? String,
           subrole.localizedCaseInsensitiveContains("secure") { return false }

        var protectedValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXProtectedContent" as CFString, &protectedValue) == .success,
           (protectedValue as? Bool) == true { return false }

        let metadataAttributes: [CFString] = [
            kAXTitleAttribute as CFString,
            kAXDescriptionAttribute as CFString,
            kAXIdentifierAttribute as CFString,
            kAXPlaceholderValueAttribute as CFString,
            kAXHelpAttribute as CFString,
            "AXRoleDescription" as CFString,
            "AXDOMIdentifier" as CFString,
            "AXDOMClassList" as CFString,
        ]
        let metadata = metadataAttributes.compactMap { stringAttribute($0, of: element) }
        if SensitiveFieldClassifier.metadataSuggestsAuthentication(metadata) { return false }

        // 웹/채팅 앱은 본문 편집기를 AXTextField나 AXComboBox로 노출하기도 한다.
        // 위의 secure/protected/authentication 검사를 통과한 편집 역할은 허용한다.
        return true
    }

    static func isCurrentContextSafe() -> Bool {
        guard !isSecureInputEnabled, !isExcludedFrontmostApp else { return false }
        if let element = focusedElement() { return isSafeTextElement(element) }
        return CompatibilityAppClassifier.supportsFallback(
            bundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        )
    }

    static func canUseCompatibilityFallback() -> Bool {
        guard !isSecureInputEnabled, !isExcludedFrontmostApp,
              CompatibilityAppClassifier.supportsFallback(
                bundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
              ) else { return false }
        // AX 정보가 있으면 반드시 안전한 편집 필드로 확인되어야 한다. 정보가 전혀 없는
        // Electron/채팅 앱에서만 Secure Input과 앱 허용목록을 이용한 대체 경로를 쓴다.
        guard let element = focusedElement() else { return true }
        return isSafeTextElement(element)
    }

    static func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    static func diagnosticDescription() -> String {
        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"
        guard let element = focusedElement() else {
            return "bundle=\(bundleID) secure=\(isSecureInputEnabled) focused=none fallback=\(CompatibilityAppClassifier.supportsFallback(bundleIdentifier: bundleID))"
        }
        let role = stringAttribute(kAXRoleAttribute as CFString, of: element) ?? "unknown"
        let subrole = stringAttribute(kAXSubroleAttribute as CFString, of: element) ?? "none"
        let rangeSettable = isSettable(kAXSelectedTextRangeAttribute as CFString, on: element)
        let selectedTextSettable = isSettable(kAXSelectedTextAttribute as CFString, on: element)
        let valueAvailable = hasAttribute(kAXValueAttribute as CFString, on: element)
        return "bundle=\(bundleID) secure=\(isSecureInputEnabled) role=\(role) subrole=\(subrole) safe=\(isSafeTextElement(element)) value=\(valueAvailable) rangeSettable=\(rangeSettable) selectedTextSettable=\(selectedTextSettable)"
    }

    private static func hasAttribute(_ attribute: CFString, on element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute, &value) == .success
    }

    private static func isSettable(_ attribute: CFString, on element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute, &settable) == .success && settable.boolValue
    }

    private static func stringAttribute(_ attribute: CFString, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }
}
