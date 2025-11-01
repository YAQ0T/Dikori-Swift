import Foundation

enum AppConfiguration {
    private static var infoDictionary: [String: Any] {
        Bundle.main.infoDictionary ?? [:]
    }

    static var apiBaseURLString: String? {
        infoDictionary["API_BASE_URL"] as? String
    }

    static var recaptchaSiteKey: String {
        (infoDictionary["RECAPTCHA_SITE_KEY"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var recaptchaAction: String {
        let configured = (infoDictionary["RECAPTCHA_ACTION"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return configured?.isEmpty == false ? configured! : "checkout"
    }

    static var recaptchaMinScore: Double {
        if let number = infoDictionary["RECAPTCHA_MIN_SCORE"] as? NSNumber {
            return number.doubleValue
        }
        if let string = infoDictionary["RECAPTCHA_MIN_SCORE"] as? String,
           let value = Double(string) {
            return value
        }
        return 0.5
    }
}
