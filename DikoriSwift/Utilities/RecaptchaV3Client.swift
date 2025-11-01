import Foundation
import SwiftUI
import WebKit

@MainActor
final class RecaptchaV3Client: NSObject, ObservableObject {
    enum RecaptchaError: LocalizedError {
        case siteKeyMissing
        case executionInProgress
        case tokenMissing
        case webError(String)

        var errorDescription: String? {
            switch self {
            case .siteKeyMissing:
                return "مفتاح reCAPTCHA غير متوفر"
            case .executionInProgress:
                return "يجري تنفيذ reCAPTCHA بالفعل"
            case .tokenMissing:
                return "تعذر الحصول على رمز التحقق"
            case .webError(let message):
                return message
            }
        }
    }

    private let siteKey: String
    private let action: String
    let minScore: Double
    fileprivate let webView: WKWebView

    private var continuation: CheckedContinuation<String, Error>?

    init(siteKey: String = AppConfiguration.recaptchaSiteKey,
         action: String = AppConfiguration.recaptchaAction,
         minScore: Double = AppConfiguration.recaptchaMinScore) {
        self.siteKey = siteKey
        self.action = action
        self.minScore = minScore

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = WKUserContentController()
        configuration.preferences.javaScriptEnabled = true

        self.webView = WKWebView(frame: .zero, configuration: configuration)

        super.init()

        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.navigationDelegate = self
        webView.configuration.userContentController.add(self, name: "recaptcha")
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "recaptcha")
    }

    func execute() async throws -> String {
        guard !siteKey.isEmpty else { throw RecaptchaError.siteKeyMissing }
        guard continuation == nil else { throw RecaptchaError.executionInProgress }

        let html = Self.buildHTML(siteKey: siteKey, action: action)
        let baseURL = URL(string: "https://www.google.com")
        webView.loadHTMLString(html, baseURL: baseURL)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    private func finish(with result: Result<String, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }

    private static func buildHTML(siteKey: String, action: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
          <head>
            <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0" />
            <script src="https://www.google.com/recaptcha/api.js?render=\(siteKey)"></script>
            <script>
              function executeRecaptcha() {
                if (!window.grecaptcha || !window.grecaptcha.execute) {
                  window.webkit.messageHandlers.recaptcha.postMessage({ error: 'UNAVAILABLE' });
                  return;
                }
                window.grecaptcha.ready(function() {
                  window.grecaptcha.execute('\(siteKey)', { action: '\(action)' }).then(function(token) {
                    window.webkit.messageHandlers.recaptcha.postMessage({ token: token || '' });
                  }).catch(function(err) {
                    window.webkit.messageHandlers.recaptcha.postMessage({ error: err && err.toString ? err.toString() : 'FAILED' });
                  });
                });
              }
            </script>
          </head>
          <body style="background: transparent; margin: 0;" onload="executeRecaptcha()">
          </body>
        </html>
        """
    }
}

extension RecaptchaV3Client: WKScriptMessageHandler {
    nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            guard message.name == "recaptcha" else { return }

            if let body = message.body as? [String: Any] {
                if let token = body["token"] as? String, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    finish(with: .success(token))
                    return
                }

                if let error = body["error"] as? String {
                    finish(with: .failure(RecaptchaError.webError(error)))
                    return
                }
            } else if let token = message.body as? String, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                finish(with: .success(token))
                return
            }

            finish(with: .failure(RecaptchaError.tokenMissing))
        }
    }
}

extension RecaptchaV3Client: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Swift.Error) {
        Task { @MainActor [weak self] in
            self?.finish(with: .failure(error))
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Swift.Error) {
        Task { @MainActor [weak self] in
            self?.finish(with: .failure(error))
        }
    }
}

struct RecaptchaWebViewContainer: UIViewRepresentable {
    @ObservedObject var client: RecaptchaV3Client

    func makeUIView(context: Context) -> WKWebView {
        client.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}