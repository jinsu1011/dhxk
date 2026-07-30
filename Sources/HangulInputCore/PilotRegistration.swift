import Foundation

public struct PilotRegistration: Codable, Equatable, Sendable {
    public let campus: String
    public let classNumber: Int
    public let name: String
    public let appVersion: String
    public let consentVersion: String

    public init(campus: String, classNumber: Int, name: String, appVersion: String, consentVersion: String) {
        self.campus = campus
        self.classNumber = classNumber
        self.name = name
        self.appVersion = appVersion
        self.consentVersion = consentVersion
    }
}

public enum PilotRegistrationValidator {
    public static let campuses = ["판교캠퍼스", "광주캠퍼스", "울산캠퍼스"]
    public static let classNumbers = Array(1...10)
    public static let consentVersion = "2026-07-30-v1"

    public static func normalizedName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    public static func validationMessage(campus: String, classNumber: Int, name rawName: String) -> String? {
        guard campuses.contains(campus) else { return "캠퍼스를 선택해 주세요." }
        guard classNumbers.contains(classNumber) else { return "반을 선택해 주세요." }
        let name = normalizedName(rawName)
        guard (2...30).contains(name.count) else { return "이름은 2~30자로 입력해 주세요." }
        guard name.range(of: #"^[가-힣A-Za-z ]+$"#, options: .regularExpression) != nil else {
            return "이름에는 한글, 영문, 공백만 사용할 수 있습니다."
        }
        return nil
    }
}

public enum PilotRegistrationReceiptValidator {
    public static func isAccepted(statusCode: Int, responseData: Data) -> Bool {
        guard (200...299).contains(statusCode),
              let object = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              object["ok"] as? Bool == true else { return false }
        return true
    }
}
