import Foundation
import HangulInputCore

enum RegistrationConfiguration {
    static var isRequired: Bool {
        Bundle.main.object(forInfoDictionaryKey: "SKALARegistrationRequired") as? Bool ?? false
    }

    static var endpoint: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "SKALARegistrationEndpoint") as? String,
              let url = URL(string: value), url.scheme == "https" else { return nil }
        return url
    }
}

final class RegistrationService {
    private let completedKey = "SKALAPilotRegistrationCompleted.2026-07-v1"
    private let defaults: UserDefaults
    private let session: URLSession

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        configuration.httpAdditionalHeaders = ["Content-Type": "application/json", "Accept": "application/json"]
        self.session = URLSession(configuration: configuration)
    }

    var isCompleted: Bool { defaults.bool(forKey: completedKey) }

    func submit(_ registration: PilotRegistration, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let endpoint = RegistrationConfiguration.endpoint else {
            completion(.failure(RegistrationError.missingEndpoint)); return
        }
        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.httpBody = try JSONEncoder().encode(registration)
            session.dataTask(with: request) { [weak self] data, response, error in
                let result: Result<Void, Error>
                if let error { result = .failure(error) }
                else if let http = response as? HTTPURLResponse, let data,
                        PilotRegistrationReceiptValidator.isAccepted(statusCode: http.statusCode, responseData: data) {
                    self?.defaults.set(true, forKey: self?.completedKey ?? "")
                    result = .success(())
                } else { result = .failure(RegistrationError.rejected) }
                DispatchQueue.main.async { completion(result) }
            }.resume()
        } catch { completion(.failure(error)) }
    }
}

private enum RegistrationError: LocalizedError {
    case missingEndpoint, rejected
    var errorDescription: String? {
        switch self {
        case .missingEndpoint: return "등록 서버 주소가 설정되지 않았습니다. 배포 담당자에게 문의해 주세요."
        case .rejected: return "등록 서버가 요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요."
        }
    }
}
