import Foundation

public enum AccessibilityTextRoleClassifier {
    public static func isEligible(
        role: String,
        valueAvailable: Bool,
        selectedRangeSettable: Bool,
        selectedTextSettable: Bool
    ) -> Bool {
        if ["AXTextField", "AXTextArea", "AXComboBox"].contains(role) { return true }
        // Chromium의 contenteditable은 AXGroup으로 노출될 수 있다. 값과 선택
        // 범위를 모두 읽고 수정할 수 있을 때만 실제 편집기로 취급한다.
        return role == "AXGroup" && valueAvailable && selectedRangeSettable && selectedTextSettable
    }
}
