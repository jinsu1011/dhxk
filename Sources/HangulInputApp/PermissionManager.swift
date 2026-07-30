import ApplicationServices
import CoreGraphics
import Foundation

struct PermissionStatus {
    let accessibility: Bool
    let inputMonitoring: Bool
    let eventSourceAvailable: Bool
    var canOperate: Bool { accessibility && inputMonitoring && eventSourceAvailable }
}

final class PermissionManager {
    func currentStatus(promptAccessibility: Bool = false) -> PermissionStatus {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: promptAccessibility] as CFDictionary
        return PermissionStatus(
            accessibility: AXIsProcessTrustedWithOptions(options),
            inputMonitoring: CGPreflightListenEventAccess(),
            eventSourceAvailable: CGEventSource(stateID: .hidSystemState) != nil
        )
    }

    func requestInputMonitoringOnce() { _ = CGRequestListenEventAccess() }
}
