import Foundation
import WebKit

@MainActor
final class RecaptchaManager: NSObject {
    static let shared = RecaptchaManager()

    struct TokenResult {
        let token: String
        let action: String
        let minScore: Double?
    }

    enum RecaptchaError: Swift.Error, LocalizedError {
        case missingSiteKey
        case busy
        case scriptFailure(reason: String?)
        case timeout
        case cancelled
        case invalidToken

        var errorDescription: String? {
            switch self {
            case .missingSiteKey:
                return "لم يتم ضبط مفتاح reCAPTCHA. حدّث إعدادات التطبيق ثم حاول من جديد."
            case .busy:
                return "هناك عملية تحقق جارية بالفعل. انتظر لحظات ثم حاول مرة أخرى."
            case .scriptFailure(let reason):
                if let reason, !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return "فشل التحقق من reCAPTCHA: \(reason)"
                }
                return "فشل التحقق من reCAPTCHA. حاول مرة أخرى لاحقًا."
            case .timeout:
                return "انتهت مهلة التحقق من reCAPTCHA. تحقق من اتصالك وأعد المحاولة."
            case .cancelled:
                return "ألغيت عملية التحقق من reCAPTCHA."
            case .invalidToken:
                return "استلم التطبيق رمز reCAPTCHA غير صالح. حاول مرة أخرى."
            }
        }
    }

    private struct Configuration {
        let siteKey: String?
        let defaultAction: String
        let minScore: Double?

        init(bundle: Bundle = .main, environment: [String: String] = ProcessInfo.processInfo.environment) {
            siteKey = Configuration.stringValue(for: "RECAPTCHA_SITE_KEY", bundle: bundle, environment: environment)

            if let action = Configuration.stringValue(for: "RECAPTCHA_DEFAULT_ACTION", bundle: bundle, environment: environment),
               !action.isEmpty {
                defaultAction = action
            } else {
                defaultAction = "checkout"
            }

            if let minScoreString = Configuration.stringValue(for: "RECAPTCHA_MIN_SCORE", bundle: bundle, environment: environment),
               let parsed = Double(minScoreString) {
                minScore = parsed
            } else {
                minScore = nil
            }
        }

        private static func stringValue(for key: String, bundle: Bundle, environment: [String: String]) -> String? {
            if let envValue = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !envValue.isEmpty {
                return envValue
            }

            guard let raw = bundle.object(forInfoDictionaryKey: key) else {
                return nil
            }

            if let string = raw as? String {
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }

            if let number = raw as? NSNumber {
                return number.stringValue
            }

            return nil
        }
    }

    private let configuration = Configuration()

    private lazy var webView: WKWebView = {
        let contentController = WKUserContentController()
        contentController.add(self, name: "recaptcha")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isHidden = true
        webView.isOpaque = false
        webView.navigationDelegate = self
        return webView
    }()

    private var pendingContinuation: CheckedContinuation<TokenResult, Swift.Error>?
    private var pendingAction: String?
    private var pendingMinScore: Double?
    private var timeoutTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    var isConfigured: Bool {
        configuration.siteKey != nil
    }

    var defaultAction: String {
        configuration.defaultAction
    }

    var defaultMinScore: Double? {
        configuration.minScore
    }

    func generateToken(for action: String? = nil, minScore: Double? = nil, timeout: TimeInterval = 15) async throws -> TokenResult {
        guard pendingContinuation == nil else {
            throw RecaptchaError.busy
        }

        guard let siteKey = configuration.siteKey, !siteKey.isEmpty else {
            throw RecaptchaError.missingSiteKey
        }

        let trimmedAction = action?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalAction = (trimmedAction?.isEmpty == false ? trimmedAction : nil) ?? configuration.defaultAction
        let finalMinScore = minScore ?? configuration.minScore

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<TokenResult, Swift.Error>) in
                guard let self else {
                    continuation.resume(throwing: RecaptchaError.scriptFailure(reason: nil))
                    return
                }

                self.pendingContinuation = continuation
                self.pendingAction = finalAction
                self.pendingMinScore = finalMinScore
                self.loadRecaptchaHTML(siteKey: siteKey, action: finalAction)

                if timeout > 0 {
                    self.timeoutTask = Task { [weak self] in
                        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                        await self?.handleTimeout()
                    }
                }
            }
        } onCancel: { [weak self] in
            Task { @MainActor [weak self] in
                self?.failCurrent(with: .cancelled)
            }
        }
    }

    private func handleTimeout() {
        failCurrent(with: .timeout)
    }

    private func loadRecaptchaHTML(siteKey: String, action: String) {
        let escapedSiteKey = RecaptchaManager.escapeForJavaScript(siteKey)
        let escapedAction = RecaptchaManager.escapeForJavaScript(action)
        let html = """
        <!doctype html>
        <html>
        <head>
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
            <script src=\"https://www.google.com/recaptcha/api.js?render=\(escapedSiteKey)\"></script>
            <script type=\"text/javascript\">
                function postMessage(payload) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.recaptcha) {
                        window.webkit.messageHandlers.recaptcha.postMessage(payload);
                    }
                }
                function executeRecaptcha() {
                    if (!window.grecaptcha || !grecaptcha.execute) {
                        setTimeout(executeRecaptcha, 150);
                        return;
                    }
                    try {
                        grecaptcha.ready(function() {
                            grecaptcha.execute('\(escapedSiteKey)', { action: '\(escapedAction)' }).then(function(token) {
                                postMessage({ token: token });
                            }).catch(function(error) {
                                var reason = error && error.message ? error.message : (error ? error.toString() : 'UNKNOWN_ERROR');
                                postMessage({ error: reason });
                            });
                        });
                    } catch (err) {
                        var message = err && err.message ? err.message : 'EXECUTION_ERROR';
                        postMessage({ error: message });
                    }
                }
                window.addEventListener('load', executeRecaptcha);
                window.addEventListener('error', function(event) {
                    postMessage({ error: event && event.message ? event.message : 'SCRIPT_ERROR' });
                });
                executeRecaptcha();
            </script>
        </head>
        <body style=\"margin:0; background:transparent;\"></body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    private static func escapeForJavaScript(_ value: String) -> String {
        var escaped = value.replacingOccurrences(of: "\\", with: "\\\\")
        escaped = escaped.replacingOccurrences(of: "'", with: "\\'")
        escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
        return escaped
    }

    private func succeedCurrent(withToken token: String) {
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            failCurrent(with: .invalidToken)
            return
        }

        let action = pendingAction ?? configuration.defaultAction
        let minScore = pendingMinScore
        pendingContinuation?.resume(returning: TokenResult(token: token, action: action, minScore: minScore))
        cleanupPendingState()
    }

    private func failCurrent(with error: RecaptchaError) {
        pendingContinuation?.resume(throwing: error)
        cleanupPendingState()
    }

    private func cleanupPendingState() {
        pendingContinuation = nil
        pendingAction = nil
        pendingMinScore = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        webView.stopLoading()
    }
}

extension RecaptchaManager: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "recaptcha" else { return }

        if let dict = message.body as? [String: Any] {
            if let token = dict["token"] as? String {
                succeedCurrent(withToken: token)
                return
            }
            if let error = dict["error"] as? String {
                failCurrent(with: .scriptFailure(reason: error))
                return
            }
        } else if let token = message.body as? String {
            succeedCurrent(withToken: token)
            return
        }

        failCurrent(with: .scriptFailure(reason: "UNKNOWN_MESSAGE"))
    }
}

extension RecaptchaManager: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Swift.Error) {
        failCurrent(with: .scriptFailure(reason: error.localizedDescription))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Swift.Error) {
        failCurrent(with: .scriptFailure(reason: error.localizedDescription))
    }
}
