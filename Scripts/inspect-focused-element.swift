#!/usr/bin/env swift

import AppKit
import ApplicationServices
import Carbon

func attribute(_ name: CFString, of element: AXUIElement) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
    return value
}

let requestedBundleID = ProcessInfo.processInfo.arguments.dropFirst().first
if let requestedBundleID {
    let deadline = Date().addingTimeInterval(30)
    while NSWorkspace.shared.frontmostApplication?.bundleIdentifier != requestedBundleID && Date() < deadline {
        Thread.sleep(forTimeInterval: 0.25)
    }
}

let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"
let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown"
let system = AXUIElementCreateSystemWide()
var focusedValue: CFTypeRef?
let focusedResult = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focusedValue)

print("frontmost=\(appName) bundle=\(bundleID)")
print("secureInput=\(IsSecureEventInputEnabled()) focusedResult=\(focusedResult.rawValue)")

guard focusedResult == .success, let focusedValue else { exit(2) }
let focused = unsafeBitCast(focusedValue, to: AXUIElement.self)

for name in [kAXRoleAttribute, kAXSubroleAttribute, kAXRoleDescriptionAttribute,
             kAXIdentifierAttribute, kAXDescriptionAttribute, kAXTitleAttribute] {
    let rendered = attribute(name as CFString, of: focused).map { String(describing: $0) } ?? "<unavailable>"
    print("\(name)=\(rendered)")
}

var names: CFArray?
if AXUIElementCopyAttributeNames(focused, &names) == .success, let names = names as? [String] {
    let safeNames = names.filter { $0 != kAXValueAttribute as String && $0 != kAXSelectedTextAttribute as String }
    print("attributes=\(safeNames.sorted().joined(separator: ","))")
}

for name in [kAXValueAttribute, kAXSelectedTextAttribute, kAXSelectedTextRangeAttribute] {
    var settable = DarwinBoolean(false)
    let result = AXUIElementIsAttributeSettable(focused, name as CFString, &settable)
    print("settable.\(name)=\(result == .success && settable.boolValue)")
}
