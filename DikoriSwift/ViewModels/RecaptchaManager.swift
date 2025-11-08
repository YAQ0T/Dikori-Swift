import Foundation

enum RecaptchaManagerError: LocalizedError {
    case sdkUnavailable
    case missingSiteKey
    case initializationFailed(String)
    case tokenFetchFailed(String)

    var errorDescription: String? {
        switch self {
        case .sdkUnavailable:
            return "خدمة reCAPTCHA غير متاحة في بيئة التطوير الحالية."
        case .missingSiteKey:
            return "مفتاح reCAPTCHA غير مُعد. يرجى تحديث إعدادات التطبيق."
        case .initializationFailed(let message):
            return "فشل تهيئة reCAPTCHA: \(message)"
        case .tokenFetchFailed(let message):
            return "تعذر الحصول على رمز reCAPTCHA: \(message)"
        }
    }
}

enum RecaptchaManagerStatus: Equatable {
    case idle
    case initializing
    case ready
    case failed(String)
    case unavailable(String)
}

#if canImport(RecaptchaEnterprise)
import RecaptchaEnterprise

@MainActor
final class RecaptchaManager: ObservableObject {
    @Published private(set) var status: RecaptchaManagerStatus = .idle

    private let siteKey: String
    private var client: RecaptchaClient?
    private var initializationTask: Task<RecaptchaClient, Error>?
    private let timeoutInMilliseconds: TimeInterval?

    init(siteKey: String? = nil,
         timeoutInMilliseconds: TimeInterval? = nil,
         autoInitialize: Bool = true) {
        self.timeoutInMilliseconds = timeoutInMilliseconds

        if let siteKey, !siteKey.isEmpty {
            self.siteKey = siteKey
        } else if let envKey = ProcessInfo.processInfo.environment["RECAPTCHA_SITE_KEY"], !envKey.isEmpty {
            self.siteKey = envKey
        } else if let plistKey = Bundle.main.object(forInfoDictionaryKey: "RECAPTCHA_SITE_KEY") as? String,
                  !plistKey.isEmpty {
            self.siteKey = plistKey
        } else {
            self.siteKey = ""
            status = .unavailable("مفتاح reCAPTCHA غير مُعد")
        }

        if autoInitialize {
            prepare()
        }
    }

    func prepare() {
        guard !siteKey.isEmpty else {
            status = .unavailable("مفتاح reCAPTCHA غير مُعد")
            return
        }

        if let client {
            status = .ready
            return
        }

        if initializationTask != nil {
            status = .initializing
            return
        }

        status = .initializing
        initializationTask = Task { [siteKey] in
            try await Recaptcha.fetchClient(withSiteKey: siteKey)
        }
    }

    func fetchLoginToken() async throws -> String {
        let client = try await ensureClient()
        do {
            if let timeoutInMilliseconds {
                return try await client.execute(withAction: RecaptchaAction.login, withTimeout: timeoutInMilliseconds)
            } else {
                return try await client.execute(withAction: RecaptchaAction.login)
            }
        } catch let error as RecaptchaError {
            status = .failed(error.errorMessage ?? error.localizedDescription)
            throw RecaptchaManagerError.tokenFetchFailed(error.errorMessage ?? error.localizedDescription)
        } catch {
            status = .failed(error.localizedDescription)
            throw RecaptchaManagerError.tokenFetchFailed(error.localizedDescription)
        }
    }

    private func ensureClient() async throws -> RecaptchaClient {
        if let client {
            return client
        }

        if siteKey.isEmpty {
            throw RecaptchaManagerError.missingSiteKey
        }

        if let initializationTask {
            do {
                let client = try await initializationTask.value
                self.client = client
                status = .ready
                self.initializationTask = nil
                return client
            } catch let error as RecaptchaError {
                status = .failed(error.errorMessage ?? error.localizedDescription)
                self.initializationTask = nil
                throw RecaptchaManagerError.initializationFailed(error.errorMessage ?? error.localizedDescription)
            } catch {
                status = .failed(error.localizedDescription)
                self.initializationTask = nil
                throw RecaptchaManagerError.initializationFailed(error.localizedDescription)
            }
        }

        status = .initializing
        let task = Task { [siteKey] in
            try await Recaptcha.fetchClient(withSiteKey: siteKey)
        }
        initializationTask = task

        do {
            let client = try await task.value
            self.client = client
            status = .ready
            initializationTask = nil
            return client
        } catch let error as RecaptchaError {
            status = .failed(error.errorMessage ?? error.localizedDescription)
            initializationTask = nil
            throw RecaptchaManagerError.initializationFailed(error.errorMessage ?? error.localizedDescription)
        } catch {
            status = .failed(error.localizedDescription)
            initializationTask = nil
            throw RecaptchaManagerError.initializationFailed(error.localizedDescription)
        }
    }
}

#else

@MainActor
final class RecaptchaManager: ObservableObject {
    @Published private(set) var status: RecaptchaManagerStatus

    init(siteKey: String? = nil,
         timeoutInMilliseconds: TimeInterval? = nil,
         autoInitialize: Bool = true) {
        status = .unavailable("SDK reCAPTCHA غير متوفر. قم بتثبيت RecaptchaEnterprise.")
    }

    func prepare() {
        // No-op when the SDK is unavailable.
    }

    func fetchLoginToken() async throws -> String {
        throw RecaptchaManagerError.sdkUnavailable
    }
}

#endif

#if DEBUG
extension RecaptchaManager {
    static func preview() -> RecaptchaManager {
        RecaptchaManager(siteKey: nil, autoInitialize: false)
    }
}
#endif
