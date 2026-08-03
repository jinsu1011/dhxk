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
        let insertedSuccessfully: Bool
        if CompatibilityAppClassifier.prefersPasteReplacement(bundleIdentifier: bundleIdentifier) {
            insertedSuccessfully = postPaste(inserted, source: source)
        } else {
            insertedSuccessfully = postUnicode(inserted, source: source)
        }
        guard insertedSuccessfully else { return false }
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
        let insertedSuccessfully: Bool
        if CompatibilityAppClassifier.prefersPasteReplacement(bundleIdentifier: bundleIdentifier) {
            insertedSuccessfully = postPaste(inserted, source: source)
        } else {
            insertedSuccessfully = postUnicode(inserted, source: source)
        }
        guard insertedSuccessfully else { return false }
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
            event.post(tap: .cghidEventTap)
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
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    // 붙여넣기 경로는 Chromium/Electron 편집기용이다. 변환문에 구분자를 포함해 한 번에
    // 붙여넣는다. 붙여넣기 직후에 구분자를 따로 보내면 Chromium이 클립보드를 비동기로
    // 읽는 탓에 구분자가 변환문보다 앞에 삽입되므로(실측: U+00A0 + 변환문) 분리하지 않는다.
    // 그 대신 ProseMirror 계열 편집기는 붙여넣은 문자열 끝의 공백을 정규화해 지운다.
    // 알려진 제약으로 문서화한다.
    private func postPaste(_ text: String, source: CGEventSource) -> Bool {
        let pasteboard = NSPasteboard.general
        let savedItems = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { return false }
        let ownedChangeCount = pasteboard.changeCount
        postKey(keyCode: 9, flags: .maskCommand, source: source)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard pasteboard.changeCount == ownedChangeCount else { return }
            pasteboard.clearContents()
            let restoredItems: [NSPasteboardItem] = savedItems.map { values in
                let item = NSPasteboardItem()
                for (type, data) in values { item.setData(data, forType: type) }
                return item
            }
            if !restoredItems.isEmpty { _ = pasteboard.writeObjects(restoredItems) }
        }
        return true
    }
}
