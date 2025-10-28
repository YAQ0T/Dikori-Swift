import Foundation

enum ContactServiceError: LocalizedError {
    case invalidResponse
    case server(message: String?, statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "استجابة غير صالحة من الخادم"
        case .server(let message, let statusCode):
            if let message, !message.isEmpty {
                return message
            } else {
                return "الخادم أعاد رمز الخطأ \(statusCode)"
            }
        }
    }
}

struct ContactRequestBody: Encodable {
    let name: String
    let email: String
    let message: String
    let recaptchaToken: String?

    init(name: String, email: String, message: String, recaptchaToken: String? = nil) {
        self.name = name
        self.email = email
        self.message = message
        self.recaptchaToken = recaptchaToken
    }
}

struct ContactSuccessResponse: Decodable {
    let message: String
}

struct ContactErrorResponse: Decodable {
    let error: String
}

final class ContactService {
    static let shared = ContactService()

    private let session: URLSession
    private let baseURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, baseURL: URL? = nil) {
        self.session = session
        if let baseURL {
            self.baseURL = baseURL
        } else if let configured = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
                  let url = URL(string: configured) {
            self.baseURL = url
        } else if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"],
                  let url = URL(string: envURL) {
            self.baseURL = url
        } else {
            self.baseURL = URL(string: "http://localhost:3001")!
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        self.decoder = decoder
    }

    @discardableResult
    func submitContactForm(name: String, email: String, message: String, recaptchaToken: String? = nil) async throws -> ContactSuccessResponse {
        let url = baseURL.appendingPathComponent("api/contact")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(ContactRequestBody(name: name, email: email, message: message, recaptchaToken: recaptchaToken))

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ContactServiceError.invalidResponse
        }

        if 200..<300 ~= httpResponse.statusCode {
            return try decoder.decode(ContactSuccessResponse.self, from: data)
        } else {
            if let errorResponse = try? decoder.decode(ContactErrorResponse.self, from: data) {
                throw ContactServiceError.server(message: errorResponse.error, statusCode: httpResponse.statusCode)
            } else {
                throw ContactServiceError.server(message: nil, statusCode: httpResponse.statusCode)
            }
        }
    }
}
