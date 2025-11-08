import SwiftUI

struct AuthFlowView: View {
    enum Step {
        case login
        case register
    }

    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var notificationsManager: NotificationsManager
    @EnvironmentObject private var ordersManager: OrdersManager
    @EnvironmentObject private var recaptchaManager: RecaptchaManager

    @State private var step: Step = .login
    @State private var statusMessage: String?

    var body: some View {
        Group {
            switch sessionManager.state {
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            case .unauthenticated:
                VStack(spacing: 24) {
                    if let message = statusMessage ?? sessionManager.lastMessage {
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    switch step {
                    case .login:
                        LoginView(onSwitchToRegister: {
                            statusMessage = nil
                            withAnimation { step = .register }
                        }) { phone, password in
                            try await performLogin(phone: phone, password: password)
                        }
                    case .register:
                        RegistrationView(onSwitchToLogin: {
                            statusMessage = nil
                            withAnimation { step = .login }
                        }) { name, phone, password in
                            try await performSignup(name: name, phone: phone, password: password)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            case .needsVerification(let context):
                SMSVerificationView(context: context) { code in
                    try await sessionManager.verify(code: code)
                } onSwitchAccount: {
                    sessionManager.logout()
                    step = .login
                }
                .onAppear {
                    statusMessage = context.message
                }
            case .authenticated:
                MainTabView()
                    .onAppear {
                        notificationsManager.authToken = sessionManager.authToken
                        ordersManager.authToken = sessionManager.authToken
                    }
            }
        }
        .onAppear {
            recaptchaManager.prepare()
            notificationsManager.authToken = sessionManager.authToken
            ordersManager.authToken = sessionManager.authToken
        }
        .onChange(of: sessionManager.session) { _, newSession in
            notificationsManager.authToken = newSession?.token
            ordersManager.authToken = newSession?.token
            if case .authenticated = sessionManager.state {
                statusMessage = nil
            }
        }
        .onChange(of: sessionManager.state) { _, newState in
            switch newState {
            case .unauthenticated:
                statusMessage = sessionManager.lastMessage
                step = .login
            case .needsVerification(let context):
                statusMessage = context.message
            default:
                break
            }
        }
        .animation(.easeInOut, value: sessionManager.state)
        .animation(.easeInOut, value: step)
    }

    private func performLogin(phone: String, password: String) async throws {
        do {
            let token = try await recaptchaManager.fetchLoginToken()
            try await sessionManager.login(phone: phone, password: password, recaptchaToken: token)
            statusMessage = nil
        } catch {
            if let recaptchaError = error as? RecaptchaManagerError {
                statusMessage = recaptchaError.localizedDescription
            } else {
                statusMessage = error.localizedDescription
            }
            throw error
        }
    }

    private func performSignup(name: String, phone: String, password: String) async throws {
        try await sessionManager.signup(name: name, phone: phone, password: password)
        statusMessage = sessionManager.lastMessage
    }
}

#Preview {
    AuthFlowView()
        .environmentObject(SessionManager.preview())
        .environmentObject(FavoritesManager())
        .environmentObject(NotificationsManager.preview())
        .environmentObject(OrdersManager.preview())
        .environmentObject(CartManager.preview())
        .environmentObject(RecaptchaManager.preview())
}
