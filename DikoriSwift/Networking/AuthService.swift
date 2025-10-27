import Foundation

enum AuthServiceError: LocalizedError {
    case invalidResponse
    case message(String)
    case statusCode(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "استجابة غير صالحة من الخادم"
        case .message(let text):
            return text
        case .statusCode(let code):
            return "الخادم أعاد رمز الخطأ \(code)"
        }
    }
}

struct AuthUserDTO: Codable, Equatable {
    let id: String
    let name: String
    let email: String?
    let phone: String?
    let role: String?
    let phoneVerified: Bool

    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case email
        case phone
        case role
        case phoneVerified
    }
}

struct AuthSession: Codable, Equatable {
    let token: String
    let user: AuthUserDTO
}

struct VerificationContext: Equatable {
    let userId: String
    let phone: String?
    let message: String?
}

enum LoginOutcome {
    case success(AuthSession)
    case requiresVerification(VerificationContext)
}

struct SignupOutcome {
    let verification: VerificationContext
}

final class AuthService {
    static let shared = AuthService()

    private let session: URLSession
    private let baseURL: URL

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
    }

    func login(phone: String, password: String) async throws -> LoginOutcome {
        let endpoint = baseURL.appendingPathComponent("api/auth/login")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload = [
            "phone": phone,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let success = try decoder.decode(LoginSuccessResponse.self, from: data)
            let session = AuthSession(token: success.token, user: success.user)
            return .success(session)
        case 403:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let pending = try decoder.decode(PendingVerificationResponse.self, from: data)
            let context = VerificationContext(
                userId: pending.userId,
                phone: pending.phone,
                message: pending.message
            )
            return .requiresVerification(context)
        case 400, 401:
            let message = try decodeMessage(from: data)
            throw AuthServiceError.message(message)
        default:
            let message = try? decodeMessage(from: data)
            if let message {
                throw AuthServiceError.message(message)
            }
            throw AuthServiceError.statusCode(httpResponse.statusCode)
        }
    }

    func signup(name: String, phone: String, password: String) async throws -> SignupOutcome {
        let endpoint = baseURL.appendingPathComponent("api/auth/signup")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload = [
            "name": name,
            "phone": phone,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 201, 200:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let signup = try decoder.decode(SignupResponse.self, from: data)
            let context = VerificationContext(
                userId: signup.userId,
                phone: signup.phone,
                message: signup.message
            )
            return SignupOutcome(verification: context)
        case 400, 409:
            let message = try decodeMessage(from: data)
            throw AuthServiceError.message(message)
        default:
            let message = try? decodeMessage(from: data)
            if let message {
                throw AuthServiceError.message(message)
            }
            throw AuthServiceError.statusCode(httpResponse.statusCode)
        }
    }

    func verifySMS(userId: String, code: String) async throws -> AuthSession {
        let endpoint = baseURL.appendingPathComponent("api/auth/verify-sms")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload = [
            "userId": userId,
            "code": code
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let verify = try decoder.decode(VerifyResponse.self, from: data)
            return AuthSession(token: verify.token, user: verify.user)
        case 400, 403, 404:
            let message = try decodeMessage(from: data)
            throw AuthServiceError.message(message)
        default:
            let message = try? decodeMessage(from: data)
            if let message {
                throw AuthServiceError.message(message)
            }
            throw AuthServiceError.statusCode(httpResponse.statusCode)
        }
    }

    private func decodeMessage(from data: Data) throws -> String {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let error = try decoder.decode(ServerMessageResponse.self, from: data)
        if let message = error.message, !message.isEmpty {
            return message
        }
        if let errorMessage = error.error, !errorMessage.isEmpty {
            return errorMessage
        }
        return "حدث خطأ غير متوقع"
    }
}

private struct LoginSuccessResponse: Decodable {
    let token: String
    let user: AuthUserDTO
}

private struct PendingVerificationResponse: Decodable {
    let message: String?
    let userId: String
    let phone: String?
}

private struct SignupResponse: Decodable {
    let message: String?
    let userId: String
    let phone: String?
}

private struct VerifyResponse: Decodable {
    let token: String
    let user: AuthUserDTO
    let message: String?
}

private struct ServerMessageResponse: Decodable {
    let message: String?
    let error: String?
}
