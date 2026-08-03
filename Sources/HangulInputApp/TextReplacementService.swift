import ApplicationServices
import Foundation

final class TextReplacementService {
    private static let maxContextUTF16Length = 256
    private let history: CorrectionHistory
    init(history: CorrectionHistory) { self.history = history }

    func focusedElement() -> AXUIElement? {
        SecurityGuard.focusedElement()
    }

    func currentToken() -> String? {
        guard !SecurityGuard.isSecureInputEnabled, !SecurityGuard.isExcludedFrontmostApp,
              let element = focusedElement(), SecurityGuard.isSafeTextElement(element),
              let context = textContext(element) else { return nil }
        return context.prefix.split(whereSeparator: Self.isBoundary).last.map(String.init)
    }

    func replaceCurrentToken(original: String, with replacement: String, delimiter: String) -> Bool {
        guard !SecurityGuard.isSecureInputEnabled, !SecurityGuard.isExcludedFrontmostApp,
              let element = focusedElement(), SecurityGuard.isSafeTextElement(element),
              let context = textContext(element) else { return false }
        let originalWithDelimiter = original + delimiter
        let replacedLength: Int
        if context.prefix.hasSuffix(originalWithDelimiter) {
            // 제안 모드: 구분 문자가 이미 대상 앱에 입력된 뒤 메뉴에서 적용한다.
            replacedLength = (originalWithDelimiter as NSString).length
        } else if context.prefix.hasSuffix(original) {
            // 자동수정 모드: 이벤트 탭이 구분 문자를 억제한 상태에서 즉시 적용한다.
            replacedLength = (original as NSString).length
        } else {
            return false
        }
        guard context.selectedRange.location >= replacedLength else { return false }
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
              let current = string(in: item.range, of: item.element),
              current == item.replacementWithDelimiter,
              setSelectedRange(item.range, on: item.element),
              AXUIElementSetAttributeValue(item.element, kAXSelectedTextAttribute as CFString, item.originalWithDelimiter as CFTypeRef) == .success
        else { return false }
        history.reject(String(item.originalWithDelimiter.dropLast()))
        history.clear()
        return true
    }

    private func textContext(_ element: AXUIElement) -> (prefix: String, selectedRange: CFRange)? {
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeBitCast(rangeValue, to: AXValue.self)
        guard AXValueGetType(axValue) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range), range.length == 0 else { return nil }
        guard range.location >= 0 else { return nil }
        let prefixLength = min(range.location, Self.maxContextUTF16Length)
        let prefixRange = CFRange(location: range.location - prefixLength, length: prefixLength)
        guard let prefix = string(in: prefixRange, of: element) else { return nil }
        return (prefix, range)
    }

    private func string(in range: CFRange, of element: AXUIElement) -> String? {
        var mutable = range
        guard let rangeValue = AXValueCreate(.cfRange, &mutable) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            rangeValue,
            &value
        ) == .success else { return nil }
        return value as? String
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
