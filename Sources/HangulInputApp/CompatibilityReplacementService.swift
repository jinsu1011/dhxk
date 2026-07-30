import AppKit
import CoreGraphics
import Foundation
import HangulInputCore

final class CompatibilityReplacementService {
    private struct Record {
        let originalWithDelimiter: String
        let replacementWithDelimiter: String
        let bundleIdentifier: String
        let createdAt: Date
    }

    private var last: Record?

    func replaceEnglishKeys(_ original: String, with replacement: String, delimiter: String) -> Bool {
        guard SecurityGuard.canUseCompatibilityFallback(),
              let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              let source = CGEventSource(stateID: .hidSystemState) else { return false }

        for _ in original { postKey(keyCode: 51, source: source) }
        let inserted = replacement + delimiter
        guard postUnicode(inserted, source: source) else { return false }
        last = Record(
            originalWithDelimiter: original + delimiter,
            replacementWithDelimiter: inserted,
            bundleIdentifier: bundleIdentifier,
            createdAt: Date()
        )
        return true
    }

    func replaceKoreanKeys(
        _ rawKeys: String,
        displayedOriginal: String,
        with replacement: String,
        delimiter: String
    ) -> Bool {
        guard SecurityGuard.canUseCompatibilityFallback(),
              DubeolsikConverter.englishKeysToHangul(rawKeys) == displayedOriginal,
              let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              let source = CGEventSource(stateID: .hidSystemState),
              postPhysicalDelimiter(delimiter, source: source) else { return false }

        // 구분 키를 먼저 전달해 macOS 한글 IME의 marked text를 확정한다. 그 다음
        // 물리 키 수가 아니라 실제 조합 문자열+구분자의 Character 수만큼 지운다.
        let originalWithDelimiter = displayedOriginal + delimiter
        for _ in originalWithDelimiter { postKey(keyCode: 51, source: source) }
        let inserted = replacement + delimiter
        guard postUnicode(inserted, source: source) else { return false }
        last = Record(
            originalWithDelimiter: originalWithDelimiter,
            replacementWithDelimiter: inserted,
            bundleIdentifier: bundleIdentifier,
            createdAt: Date()
        )
        return true
    }

    func undoLast() -> Bool {
        guard let last, Date().timeIntervalSince(last.createdAt) <= 30,
              SecurityGuard.canUseCompatibilityFallback(),
              NSWorkspace.shared.frontmostApplication?.bundleIdentifier == last.bundleIdentifier,
              let source = CGEventSource(stateID: .hidSystemState) else { return false }
        for _ in last.replacementWithDelimiter { postKey(keyCode: 51, source: source) }
        guard postUnicode(last.originalWithDelimiter, source: source) else { return false }
        self.last = nil
        return true
    }

    private func postKey(keyCode: CGKeyCode, flags: CGEventFlags = [], source: CGEventSource) {
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown) else { continue }
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: KeyboardEventMonitor.syntheticMarker)
            event.post(tap: .cgSessionEventTap)
        }
    }

    private func postPhysicalDelimiter(_ delimiter: String, source: CGEventSource) -> Bool {
        let mapping: [String: (CGKeyCode, Bool)] = [
            " ": (49, false), "\n": (36, false), "\t": (48, false),
            ",": (43, false), "<": (43, true), ".": (47, false), ">": (47, true),
            "/": (44, false), "?": (44, true), ";": (41, false), ":": (41, true),
            "'": (39, false), "\"": (39, true), "[": (33, false), "{": (33, true),
            "]": (30, false), "}": (30, true), "\\": (42, false), "|": (42, true),
            "!": (18, true), "(": (25, true), ")": (29, true),
        ]
        guard let (keyCode, shifted) = mapping[delimiter] else { return false }
        postKey(keyCode: keyCode, flags: shifted ? .maskShift : [], source: source)
        return true
    }

    private func postUnicode(_ text: String, source: CGEventSource) -> Bool {
        let units = Array(text.utf16)
        guard !units.isEmpty,
              let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return false }
        down.setIntegerValueField(.eventSourceUserData, value: KeyboardEventMonitor.syntheticMarker)
        up.setIntegerValueField(.eventSourceUserData, value: KeyboardEventMonitor.syntheticMarker)
        units.withUnsafeBufferPointer {
            down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: $0.baseAddress!)
            up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: $0.baseAddress!)
        }
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
        return true
    }
}
