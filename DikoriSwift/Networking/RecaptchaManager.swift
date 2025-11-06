import Foundation

#if canImport(RecaptchaEnterprise)
import RecaptchaEnterprise
#endif

enum RecaptchaManagerError: LocalizedError {
    case siteKeyMissing
    case unsupportedPlatform
    case tokenGenerationFailed
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .siteKeyMissing:
            return "لم يتم إعداد مفتاح reCAPTCHA بشكل صحيح."
        case .unsupportedPlatform:
            return "هذه المنصة لا تدعم reCAPTCHA."
        case .tokenGenerationFailed:
            return "تعذّر الحصول على رمز التحقق. حاول مرة أخرى."
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

@MainActor
final class RecaptchaManager {
    static let shared = RecaptchaManager()

    private let siteKey: String

    #if canImport(RecaptchaEnterprise)
    private var client: RecaptchaClient?
    #endif

    init(siteKey: String? = nil) {
        if let provided = siteKey?.trimmingCharacters(in: .whitespacesAndNewlines), !provided.isEmpty {
            self.siteKey = provided
        } else if let configured = Bundle.main.object(forInfoDictionaryKey: "RECAPTCHA_SITE_KEY") as? String,
                  !configured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.siteKey = configured.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let envValue = ProcessInfo.processInfo.environment["RECAPTCHA_SITE_KEY"],
                  !envValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.siteKey = envValue.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            self.siteKey = ""
        }
    }

    func fetchToken(action: String) async throws -> String {
        let trimmedAction = action.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedAction = trimmedAction.isEmpty ? "checkout" : trimmedAction

        guard !siteKey.isEmpty else {
            throw RecaptchaManagerError.siteKeyMissing
        }

        #if canImport(RecaptchaEnterprise)
        let activeClient = try obtainClient()
        return try await execute(on: activeClient, action: resolvedAction)
        #else
        throw RecaptchaManagerError.unsupportedPlatform
        #endif
    }

    #if canImport(RecaptchaEnterprise)
    private func obtainClient() throws -> RecaptchaClient {
        if let existing = client {
            return existing
        }

        do {
            let created = try Recaptcha.getClient(withSiteKey: siteKey)
            client = created
            return created
        } catch {
            throw RecaptchaManagerError.underlying(error)
        }
    }

    private func execute(on client: RecaptchaClient, action: String) async throws -> String {
        let recaptchaAction = RecaptchaAction(action: action)

        return try await withCheckedThrowingContinuation { continuation in
            client.execute(withAction: recaptchaAction) { token, error in
                if let error {
                    continuation.resume(throwing: RecaptchaManagerError.underlying(error))
                    return
                }

                guard let token, !token.isEmpty else {
                    continuation.resume(throwing: RecaptchaManagerError.tokenGenerationFailed)
                    return
                }

                continuation.resume(returning: token)
            }
        }
    }
    #endif
}

#if DEBUG
extension RecaptchaManager {
    static func preview() -> RecaptchaManager {
        RecaptchaManager(siteKey: "preview")
    }
}
#endif
