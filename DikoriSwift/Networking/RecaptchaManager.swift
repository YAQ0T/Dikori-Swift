import Foundation
import RecaptchaEnterprise

enum RecaptchaManagerError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "فشل في الحصول على رمز التحقق من reCAPTCHA"
        }
    }
}

@MainActor
final class RecaptchaManager {
    static let shared = RecaptchaManager()

    private var isConfigured = false

    private init() {}

    func configure() {
        guard !isConfigured else { return }
        Recaptcha.initialize(siteKey: "6LcENrsrAAAAALomNaP-d0iFoJIIglAqX2uWfMWH")
        isConfigured = true
    }

    func fetchToken(action: String) async throws -> String {
        if !isConfigured {
            configure()
        }

        return try await withCheckedThrowingContinuation { continuation in
            Recaptcha.shared.execute(action: action) { token, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let token {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: RecaptchaManagerError.missingToken)
                }
            }
        }
    }
}
