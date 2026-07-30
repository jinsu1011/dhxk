import Foundation
import HangulInputCore

func runPilotRegistrationTests(_ suite: TestSuite) {
    for campus in PilotRegistrationValidator.campuses {
        suite.expect(PilotRegistrationValidator.validationMessage(campus: campus, classNumber: 1, name: "홍길동") == nil, "등록 캠퍼스 허용: \(campus)")
    }
    for number in PilotRegistrationValidator.classNumbers {
        suite.expect(PilotRegistrationValidator.validationMessage(campus: "판교캠퍼스", classNumber: number, name: "홍길동") == nil, "등록 반 허용: \(number)반")
    }
    suite.expect(PilotRegistrationValidator.normalizedName("  김  진수  ") == "김 진수", "등록 이름 공백 정규화")
    suite.expect(PilotRegistrationValidator.validationMessage(campus: "서울", classNumber: 1, name: "홍길동") != nil, "미허용 캠퍼스 거부")
    suite.expect(PilotRegistrationValidator.validationMessage(campus: "판교캠퍼스", classNumber: 11, name: "홍길동") != nil, "미허용 반 거부")
    for invalid in ["홍", "=IMPORTXML", "홍길동1", "홍_길동", ""] {
        suite.expect(PilotRegistrationValidator.validationMessage(campus: "판교캠퍼스", classNumber: 1, name: invalid) != nil, "안전하지 않은 이름 거부: \(invalid)")
    }
    suite.expect(PilotRegistrationReceiptValidator.isAccepted(statusCode: 200, responseData: Data(#"{"ok":true}"#.utf8)), "성공 응답만 등록 완료")
    suite.expect(!PilotRegistrationReceiptValidator.isAccepted(statusCode: 500, responseData: Data(#"{"ok":true}"#.utf8)), "서버 오류는 등록 미완료")
    suite.expect(!PilotRegistrationReceiptValidator.isAccepted(statusCode: 200, responseData: Data(#"{"ok":false}"#.utf8)), "거절 응답은 등록 미완료")
    suite.expect(!PilotRegistrationReceiptValidator.isAccepted(statusCode: 200, responseData: Data("not-json".utf8)), "비정상 응답은 등록 미완료")
}
