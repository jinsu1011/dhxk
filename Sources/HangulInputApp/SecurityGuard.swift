import AppKit
import Carbon
import ApplicationServices
import HangulInputCore

enum SecurityGuard {
    private static var enhancedAccessibilityPIDs = Set<pid_t>()
    private static let defaultExcludedBundleIDs: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "com.microsoft.VSCode",
        "com.apple.dt.Xcode", "com.jetbrains.intellij", "com.jetbrains.CLion",
        "com.microsoft.rdc.macos", "com.teamviewer.TeamViewer",
    ]

    static var isSecureInputEnabled: Bool { IsSecureEventInputEnabled() }

    @discardableResult
    static func prepareAccessibility(for application: NSRunningApplication?) -> AXError? {
        guard let application, !application.isTerminated else { return nil }
        let element = AXUIElementCreateApplication(application.processIdentifier)
        if CompatibilityAppClassifier.requiresEnhancedAccessibility(
            bundleIdentifier: application.bundleIdentifier
        ) {
            let result = AXUIElementSetAttributeValue(
                element, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue
            )
            if result == .success { enhancedAccessibilityPIDs.insert(application.processIdentifier) }
            return result
        }
        guard CompatibilityAppClassifier.requiresManualAccessibility(
            bundleIdentifier: application.bundleIdentifier
        ) else { return nil }
        return AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }

    static func releasePreparedAccessibility() {
        for pid in enhancedAccessibilityPIDs {
            let element = AXUIElementCreateApplication(pid)
            _ = AXUIElementSetAttributeValue(
                element, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse
            )
        }
        enhancedAccessibilityPIDs.removeAll()
    }

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
              AccessibilityTextRoleClassifier.isEligible(
                role: role,
                valueAvailable: hasAttribute(kAXValueAttribute as CFString, on: element),
                selectedRangeSettable: isSettable(kAXSelectedTextRangeAttribute as CFString, on: element),
                selectedTextSettable: isSettable(kAXSelectedTextAttribute as CFString, on: element)
              )
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
        guard let element = focusedElement() else { return false }
        return isSafeTextElement(element)
    }

    static func canUseCompatibilityFallback() -> Bool {
        guard !isSecureInputEnabled, !isExcludedFrontmostApp,
              CompatibilityAppClassifier.supportsFallback(
                bundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
              ) else { return false }
        // 포커스된 AX 요소를 확인할 수 없으면 로그인/인증 입력창과 일반 본문을
        // 구분할 근거가 없으므로 호환 앱에서도 fail-closed로 차단한다.
        guard let element = focusedElement() else { return false }
        return isSafeTextElement(element)
    }

    static func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value) == .success,
           let value {
            return unsafeBitCast(value, to: AXUIElement.self)
        }

        // Chromium/Electron 앱은 시스템 전역 AX 조회에는 포커스 요소를 반환하지
        // 않지만 앱 AX 루트에는 반환하는 경우가 있다. 현재 전면 앱으로 범위를
        // 제한해 다시 조회하며, 여기서도 실패하면 기존처럼 fail-closed 한다.
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              !frontmost.isTerminated else { return nil }
        let application = AXUIElementCreateApplication(frontmost.processIdentifier)
        if let focused = focusedElement(in: application) { return focused }

        // Electron 공식 접근성 경로다. Chromium 기반 호환 앱이 접근성 트리를
        // 지연 생성한 경우에만 활성화하고, 활성화 뒤에도 요소가 없으면 차단한다.
        if CompatibilityAppClassifier.requiresManualAccessibility(bundleIdentifier: frontmost.bundleIdentifier) ||
            CompatibilityAppClassifier.requiresEnhancedAccessibility(bundleIdentifier: frontmost.bundleIdentifier) {
            _ = prepareAccessibility(for: frontmost)
            if let focused = focusedElement(in: application) { return focused }
        }
        if CompatibilityAppClassifier.supportsFallback(bundleIdentifier: frontmost.bundleIdentifier),
           let focused = focusedEditableDescendant(in: application) {
            return focused
        }
        return nil
    }

    private static func focusedElement(in application: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &value) == .success,
           let value {
            return unsafeBitCast(value, to: AXUIElement.self)
        }

        // 일부 Electron 앱은 포커스 요소를 앱 루트가 아니라 포커스 창에만
        // 노출한다. 창 자체를 확인한 뒤 같은 속성을 한 번 더 조회한다.
        var windowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
              let windowValue else { return nil }
        let window = unsafeBitCast(windowValue, to: AXUIElement.self)
        value = nil
        guard AXUIElementCopyAttributeValue(window, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private static func focusedEditableDescendant(in application: AXUIElement) -> AXUIElement? {
        var queue: [(AXUIElement, Int)] = [(application, 0)]
        var visited = Set<CFHashCode>()
        var index = 0
        let maximumElements = 300
        let maximumDepth = 16

        while index < queue.count, index < maximumElements {
            let (element, depth) = queue[index]
            index += 1
            let identity = CFHash(element)
            guard visited.insert(identity).inserted else { continue }

            var focusedValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXFocusedAttribute as CFString, &focusedValue) == .success,
               (focusedValue as? Bool) == true,
               isSafeTextElement(element) {
                return element
            }

            guard depth < maximumDepth else { continue }
            var childrenValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
                  let children = childrenValue as? [AXUIElement] else { continue }
            for child in children.prefix(100) {
                queue.append((child, depth + 1))
                if queue.count >= maximumElements { break }
            }
        }
        return nil
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
