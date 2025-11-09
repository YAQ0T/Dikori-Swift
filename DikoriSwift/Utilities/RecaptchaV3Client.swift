import Foundation
import WebKit

enum RecaptchaV3Error: LocalizedError {
    case initializationFailed(String?)
    case executionInProgress
    case notReady
    case tokenNotReceived
    case javaScriptError(String)
    case evaluationFailed(String)
    case unexpectedMessage

    var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            if let message, !message.isEmpty {
                return "تعذّر تحميل خدمة reCAPTCHA: \(message)"
            }
            return "تعذّر تحميل خدمة reCAPTCHA. حاول مرة أخرى لاحقًا."
        case .executionInProgress:
            return "يوجد طلب reCAPTCHA قيد التنفيذ. يرجى الانتظار لحظات والمحاولة مجددًا."
        case .notReady:
            return "خدمة reCAPTCHA غير جاهزة بعد. حاول إعادة المحاولة بعد قليل."
        case .tokenNotReceived:
            return "لم يتم استلام رمز التحقق من reCAPTCHA. حاول مرة أخرى."
        case .javaScriptError(let message):
            return "فشل تنفيذ reCAPTCHA: \(message)"
        case .evaluationFailed(let message):
            return "تعذّر تنفيذ برنامج reCAPTCHA النصي: \(message)"
        case .unexpectedMessage:
            return "استجابة غير متوقعة من reCAPTCHA."
        }
    }
}

@MainActor
final class RecaptchaV3Client: NSObject {
    private static let messageHandlerName = "recaptcha"

    private let siteKey: String
    private let webView: WKWebView

    private var readyContinuation: CheckedContinuation<Void, Error>?
    private var tokenContinuation: CheckedContinuation<String, Error>?
    private var isReady = false

    private init(siteKey: String) {
        self.siteKey = siteKey

        let contentController = WKUserContentController()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.websiteDataStore = .nonPersistent()

        self.webView = WKWebView(frame: .zero, configuration: configuration)

        super.init()

        contentController.add(self, name: Self.messageHandlerName)
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: Self.messageHandlerName)
    }

    static func fetchClient(siteKey: String) async throws -> RecaptchaV3Client {
        let client = RecaptchaV3Client(siteKey: siteKey)
        try await client.prepareWebView()
        return client
    }

    func execute(action: String) async throws -> String {
        guard isReady else { throw RecaptchaV3Error.notReady }
        if tokenContinuation != nil { throw RecaptchaV3Error.executionInProgress }

        let script = "window.recaptchaExecute(\(Self.javascriptLiteral(for: action)));"

        return try await withCheckedThrowingContinuation { continuation in
            tokenContinuation = continuation

            webView.evaluateJavaScript(script) { [weak self] _, error in
                guard let self else { return }
                if let error {
                    self.finishTokenRequest(with: .failure(RecaptchaV3Error.evaluationFailed(error.localizedDescription)))
                }
            }
        }
    }

    private func prepareWebView() async throws {
        if isReady { return }

        let html = Self.htmlTemplate(siteKey: siteKey)

        try await withCheckedThrowingContinuation { continuation in
            readyContinuation = continuation
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    private func finishTokenRequest(with result: Result<String, Error>) {
        guard let continuation = tokenContinuation else { return }
        tokenContinuation = nil
        switch result {
        case .success(let token):
            continuation.resume(returning: token)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    private func notifyReady() {
        isReady = true
        readyContinuation?.resume()
        readyContinuation = nil
    }

    private func failInitialization(with error: Error) {
        readyContinuation?.resume(throwing: error)
        readyContinuation = nil
    }

    private static func htmlTemplate(siteKey: String) -> String {
        let jsonSiteKey = javascriptLiteral(for: siteKey)
        let encodedSiteKey = urlEncodedSiteKey(siteKey)

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
            <script>
                window.recaptchaSiteKey = \(jsonSiteKey);
                window.recaptchaNotify = function(message) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.recaptcha) {
                        window.webkit.messageHandlers.recaptcha.postMessage(message);
                    }
                };
                window.recaptchaExecute = function(action) {
                    if (!window.grecaptcha) {
                        window.recaptchaNotify({ type: 'error', error: 'grecaptcha is not ready' });
                        return;
                    }
                    grecaptcha.execute(window.recaptchaSiteKey, { action: action })
                        .then(function(token) {
                            window.recaptchaNotify({ type: 'token', token: token });
                        })
                        .catch(function(error) {
                            window.recaptchaNotify({ type: 'error', error: String(error) });
                        });
                };
                window.recaptchaOnLoad = function() {
                    if (!window.grecaptcha) {
                        window.recaptchaNotify({ type: 'error', error: 'Unable to load reCAPTCHA' });
                        return;
                    }
                    grecaptcha.ready(function() {
                        window.recaptchaNotify({ type: 'ready' });
                    });
                };
            </script>
            <script src=\"https://www.google.com/recaptcha/api.js?render=\(encodedSiteKey)&onload=recaptchaOnLoad\" async defer></script>
            <style>
                body { background-color: transparent; }
            </style>
        </head>
        <body></body>
        </html>
        """
    }

    private static func javascriptLiteral(for string: String) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: [string], options: []),
           let array = String(data: data, encoding: .utf8) {
            let start = array.index(after: array.startIndex)
            let end = array.index(before: array.endIndex)
            return String(array[start..<end])
        }
        return "'\(string.replacingOccurrences(of: "'", with: "\\'"))'"
    }

    private static func urlEncodedSiteKey(_ siteKey: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_")
        return siteKey.addingPercentEncoding(withAllowedCharacters: allowed) ?? siteKey
    }
}

extension RecaptchaV3Client: WKScriptMessageHandler {
    nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            if message.name != Self.messageHandlerName {
                return
            }

            if let body = message.body as? [String: Any], let type = body["type"] as? String {
                switch type {
                case "ready":
                    notifyReady()
                case "token":
                    if let token = body["token"] as? String, !token.isEmpty {
                        finishTokenRequest(with: .success(token))
                    } else {
                        finishTokenRequest(with: .failure(RecaptchaV3Error.tokenNotReceived))
                    }
                case "error":
                    let message = (body["error"] as? String) ?? "غير معروف"
                    if readyContinuation != nil && !isReady {
                        failInitialization(with: RecaptchaV3Error.initializationFailed(message))
                    } else {
                        finishTokenRequest(with: .failure(RecaptchaV3Error.javaScriptError(message)))
                    }
                default:
                    finishTokenRequest(with: .failure(RecaptchaV3Error.unexpectedMessage))
                }
            } else {
                finishTokenRequest(with: .failure(RecaptchaV3Error.unexpectedMessage))
            }
        }
    }
}

extension RecaptchaV3Client: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        failInitialization(with: RecaptchaV3Error.initializationFailed(error.localizedDescription))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        failInitialization(with: RecaptchaV3Error.initializationFailed(error.localizedDescription))
    }
}
