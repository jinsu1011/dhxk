import ApplicationServices
import Foundation

final class TextReplacementService {
    private let history: CorrectionHistory
    init(history: CorrectionHistory) { self.history = history }

    func focusedElement() -> AXUIElement? {
        SecurityGuard.focusedElement()
    }

    func currentToken() -> String? {
        guard !SecurityGuard.isSecureInputEnabled, !SecurityGuard.isExcludedFrontmostApp,
              let element = focusedElement(), SecurityGuard.isSafeTextElement(element),
              let context = textContext(element) else { return nil }
        let prefix = String(context.value.prefix(context.caretCharacterOffset))
        return prefix.split(whereSeparator: Self.isBoundary).last.map(String.init)
    }

    func replaceCurrentToken(original: String, with replacement: String, delimiter: String) -> Bool {
        guard !SecurityGuard.isSecureInputEnabled, !SecurityGuard.isExcludedFrontmostApp,
              let element = focusedElement(), SecurityGuard.isSafeTextElement(element),
              let context = textContext(element) else { return false }
        let nsValue = context.value as NSString
        let prefix = nsValue.substring(to: context.selectedRange.location)
        let originalWithDelimiter = original + delimiter
        let replacedLength: Int
        if prefix.hasSuffix(originalWithDelimiter) {
            // 제안 모드: 구분 문자가 이미 대상 앱에 입력된 뒤 메뉴에서 적용한다.
            replacedLength = (originalWithDelimiter as NSString).length
        } else if prefix.hasSuffix(original) {
            // 자동수정 모드: 이벤트 탭이 구분 문자를 억제한 상태에서 즉시 적용한다.
            replacedLength = (original as NSString).length
        } else {
            return false
        }
        let range = CFRange(location: context.selectedRange.location - replacedLength, length: replacedLength)
        let inserted = replacement + delimiter
        guard setSelectedRange(range, on: element),
              AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, inserted as CFTypeRef) == .success
        else { return false }
        history.record(CorrectionRecord(
            element: element,
            range: CFRange(location: range.location, length: (inserted as NSString).length),
            originalWithDelimiter: originalWithDelimiter,
            replacementWithDelimiter: inserted
        ))
        history.accept(original)
        return true
    }

    func undoLast() -> Bool {
        guard !SecurityGuard.isSecureInputEnabled, !SecurityGuard.isExcludedFrontmostApp,
              let item = history.last,
              let focused = focusedElement(), CFEqual(focused, item.element),
              SecurityGuard.isSafeTextElement(item.element),
              let current = value(of: item.element) else { return false }
        let ns = current as NSString
        guard item.range.location + item.range.length <= ns.length,
              ns.substring(with: NSRange(location: item.range.location, length: item.range.length)) == item.replacementWithDelimiter,
              setSelectedRange(item.range, on: item.element),
              AXUIElementSetAttributeValue(item.element, kAXSelectedTextAttribute as CFString, item.originalWithDelimiter as CFTypeRef) == .success
        else { return false }
        history.reject(String(item.originalWithDelimiter.dropLast()))
        history.clear()
        return true
    }

    private func value(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func textContext(_ element: AXUIElement) -> (value: String, selectedRange: CFRange, caretCharacterOffset: Int)? {
        guard let value = value(of: element) else { return nil }
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeBitCast(rangeValue, to: AXValue.self)
        guard AXValueGetType(axValue) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range), range.length == 0 else { return nil }
        let ns = value as NSString
        guard range.location >= 0, range.location <= ns.length else { return nil }
        let characterOffset = String(ns.substring(to: range.location)).count
        return (value, range, characterOffset)
    }

    private func setSelectedRange(_ range: CFRange, on element: AXUIElement) -> Bool {
        var mutable = range
        guard let value = AXValueCreate(.cfRange, &mutable) else { return false }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value) == .success
    }

    private static func isBoundary(_ character: Character) -> Bool {
        character.isWhitespace || ",.!?;:()[]{}\"'".contains(character)
    }
}
