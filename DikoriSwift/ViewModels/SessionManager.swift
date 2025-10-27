import Foundation

@MainActor
final class SessionManager: ObservableObject, AuthTokenProviding {
    enum State: Equatable {
        case loading
        case unauthenticated
        case needsVerification(VerificationContext)
        case authenticated(AuthSession)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading), (.unauthenticated, .unauthenticated):
                return true
            case (.needsVerification(let l), .needsVerification(let r)):
                return l.userId == r.userId && l.phone == r.phone && l.message == r.message
            case (.authenticated(let l), .authenticated(let r)):
                return l == r
            default:
                return false
            }
        }
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var session: AuthSession? {
        didSet {
            tokenCache.set(session?.token)
        }
    }
    @Published private(set) var lastMessage: String?

    nonisolated var authToken: String? { tokenCache.get() }

    private let authService: AuthService
    private let storage: CredentialsStorage
    private let storageKey = "auth.session"
    private let tokenCache = TokenCache()

    init(authService: AuthService = .shared,
         storage: CredentialsStorage = KeychainCredentialsStorage()) {
        self.authService = authService
        self.storage = storage

        tokenCache.set(session?.token)

        ProductService.shared.tokenProvider = self
        NotificationService.shared.tokenProvider = self
        OrderService.shared.tokenProvider = self

        Task {
            await restoreSessionIfNeeded()
        }
    }

    func restoreSessionIfNeeded() async {
        if session != nil { return }
        state = .loading
        do {
            if let stored: AuthSession = try storage.load(AuthSession.self, for: storageKey) {
                session = stored
                state = .authenticated(stored)
                lastMessage = nil
            } else {
                state = .unauthenticated
                lastMessage = nil
            }
        } catch {
            state = .unauthenticated
            lastMessage = nil
        }
    }

    func login(phone: String, password: String) async throws {
        let outcome = try await authService.login(phone: phone, password: password)
        switch outcome {
        case .success(let session):
            try persist(session: session)
            self.session = session
            state = .authenticated(session)
            lastMessage = nil
        case .requiresVerification(let context):
            try clearStoredSession()
            self.session = nil
            state = .needsVerification(context)
            lastMessage = context.message
        }
    }

    func signup(name: String, phone: String, password: String) async throws {
        let outcome = try await authService.signup(name: name, phone: phone, password: password)
        try clearStoredSession()
        session = nil
        state = .needsVerification(outcome.verification)
        lastMessage = outcome.verification.message
    }

    func verify(code: String) async throws {
        guard case .needsVerification(let context) = state else {
            throw AuthServiceError.message("لا توجد عملية تحقق نشطة")
        }

        let session = try await authService.verifySMS(userId: context.userId, code: code)
        try persist(session: session)
        self.session = session
        state = .authenticated(session)
        lastMessage = nil
    }

    func logout() {
        session = nil
        try? clearStoredSession()
        state = .unauthenticated
        lastMessage = nil
    }

    private func persist(session: AuthSession) throws {
        try storage.save(session, for: storageKey)
    }

    private func clearStoredSession() throws {
        try storage.removeValue(for: storageKey)
    }
}

private final class TokenCache: @unchecked Sendable {
    private var token: String?
    private let lock = NSLock()

    func get() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return token
    }

    func set(_ token: String?) {
        lock.lock()
        defer { lock.unlock() }
        self.token = token
    }
}

#if DEBUG
extension SessionManager {
    private final class PreviewCredentialsStorage: CredentialsStorage {
        private let storedData: Data?
        private let encoder = JSONEncoder()
        private let decoder = JSONDecoder()

        init(session: AuthSession?) {
            if let session, let data = try? encoder.encode(session) {
                self.storedData = data
            } else {
                self.storedData = nil
            }
        }

        func save<T>(_ value: T, for key: String) throws where T: Decodable, T: Encodable {
            // No-op for previews
        }

        func load<T>(_ type: T.Type, for key: String) throws -> T? where T: Decodable, T: Encodable {
            guard let storedData else { return nil }
            return try decoder.decode(T.self, from: storedData)
        }

        func removeValue(for key: String) throws {
            // No-op for previews
        }
    }

    static func preview(session: AuthSession? = AuthSession(
        token: "",
        user: AuthUserDTO(
            id: "user-preview",
            name: "مستخدم ديكوري",
            email: "preview@dikori.app",
            phone: "+972500000000",
            role: "customer",
            phoneVerified: true
        )
    )) -> SessionManager {
        let storage = PreviewCredentialsStorage(session: session)
        let manager = SessionManager(authService: AuthService(), storage: storage)

        if let session {
            manager.session = session
            manager.state = .authenticated(session)
        } else {
            manager.session = nil
            manager.state = .unauthenticated
        }

        manager.lastMessage = nil
        return manager
    }
}
#endif
