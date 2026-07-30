import CoreGraphics
import Foundation

protocol KeyboardEventMonitorDelegate: AnyObject {
    func keyboardMonitorDidReachBoundary(rawKeys: String, delimiter: String) -> Bool
    func keyboardMonitorDidRequestUndo()
    func keyboardMonitorDidResetBuffer()
}

final class KeyboardEventMonitor {
    static let syntheticMarker: Int64 = 0x48494658
    weak var delegate: KeyboardEventMonitorDelegate?
    private var eventTap: CFMachPort?
    private var source: CFRunLoopSource?
    private var buffer = ""
    private var unsafeTokenContext = false
    private let debug = ProcessInfo.processInfo.environment["HIF_DEBUG"] == "1"

    private static let keyMap: [Int64: (String, String)] = [
        0:("a","A"),1:("s","S"),2:("d","D"),3:("f","F"),4:("h","H"),5:("g","G"),6:("z","Z"),7:("x","X"),8:("c","C"),9:("v","V"),
        11:("b","B"),12:("q","Q"),13:("w","W"),14:("e","E"),15:("r","R"),16:("y","Y"),17:("t","T"),31:("o","O"),32:("u","U"),34:("i","I"),35:("p","P"),37:("l","L"),38:("j","J"),40:("k","K"),45:("n","N"),46:("m","M")
    ]
    private static let delimiters: [Int64: (String, String)] = [
        49:(" "," "),36:("\n","\n"),48:("\t","\t"),43:(",","<"),47:(".",">"),44:("/","?"),41:(";",":"),39:("'","\""),33:("[","{"),30:("]","}"),42:("\\","|")
    ]
    private static let shiftedSentenceDelimiters: [Int64: String] = [18:"!", 25:"(", 29:")"]

    func start() -> Bool {
        guard eventTap == nil else { return true }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<KeyboardEventMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handle(type: type, event: event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: CGEventMask(mask), callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        source = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let eventTap { CFMachPortInvalidate(eventTap) }
        source = nil; eventTap = nil; reset(clearContext: true, invalidateSuggestion: true)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard event.getIntegerValueField(.eventSourceUserData) != Self.syntheticMarker else {
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { reset(clearContext: true, invalidateSuggestion: true); return Unmanaged.passUnretained(event) }
        guard SecurityGuard.isCurrentContextSafe() else {
            if debug { NSLog("[dhxk] blocked context: %@", SecurityGuard.diagnosticDescription()) }
            reset(clearContext: true, invalidateSuggestion: true)
            return Unmanaged.passUnretained(event)
        }
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
            if keyCode == 6 && flags.contains(.maskCommand) && flags.contains(.maskAlternate) {
                delegate?.keyboardMonitorDidRequestUndo()
            }
            reset(clearContext: true, invalidateSuggestion: true)
            return Unmanaged.passUnretained(event)
        }
        if [123,124,125,126,53].contains(keyCode) { reset(clearContext: true, invalidateSuggestion: true); return Unmanaged.passUnretained(event) }
        if keyCode == 51 { if !buffer.isEmpty { buffer.removeLast() }; return Unmanaged.passUnretained(event) }
        let shifted = flags.contains(.maskShift)
        if shifted, let delimiter = Self.shiftedSentenceDelimiters[keyCode] {
            let handled = !unsafeTokenContext && !buffer.isEmpty && (delegate?.keyboardMonitorDidReachBoundary(rawKeys: buffer, delimiter: delimiter) ?? false)
            reset()
            return handled ? nil : Unmanaged.passUnretained(event)
        }
        if let pair = Self.delimiters[keyCode] {
            let delimiter = shifted ? pair.1 : pair.0
            if delimiter == "/" || delimiter == "\\" { unsafeTokenContext = true }
            let handled = !unsafeTokenContext && !buffer.isEmpty && (delegate?.keyboardMonitorDidReachBoundary(rawKeys: buffer, delimiter: delimiter) ?? false)
            let clearsContext = delimiter == " " || delimiter == "\n" || delimiter == "\t"
            reset(clearContext: clearsContext)
            return handled ? nil : Unmanaged.passUnretained(event)
        }
        if let pair = Self.keyMap[keyCode] {
            if buffer.isEmpty { delegate?.keyboardMonitorDidResetBuffer() }
            buffer += shifted ? pair.1 : pair.0
        } else {
            // 숫자, @, _, 괄호 등은 URL·이메일·경로·코드 조각일 수 있으므로
            // 다음 공백 전까지 해당 토큰 전체를 제외한다.
            unsafeTokenContext = true
            reset(invalidateSuggestion: true)
        }
        return Unmanaged.passUnretained(event)
    }

    private func reset(clearContext: Bool = false, invalidateSuggestion: Bool = false) {
        buffer = ""
        if clearContext { unsafeTokenContext = false }
        if invalidateSuggestion { delegate?.keyboardMonitorDidResetBuffer() }
    }
}
