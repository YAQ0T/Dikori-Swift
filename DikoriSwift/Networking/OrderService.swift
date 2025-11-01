import Foundation

enum OrderServiceError: LocalizedError {
    case invalidResponse
    case statusCode(Int)
    case message(String, code: Int?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "استجابة غير صالحة من الخادم"
        case .statusCode(let code):
            return "الخادم أعاد رمز الخطأ \(code)"
        case .message(let text, _):
            return text
        }
    }
}

final class OrderService {
    static let shared = OrderService()

    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    weak var tokenProvider: (any AuthTokenProviding)?

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

        self.decoder = ISO8601Decoder.makeDecoder()
        self.encoder = JSONEncoder()
    }

    func fetchMyOrders(token overrideToken: String? = nil) async throws -> [Order] {
        let endpoint = baseURL.appendingPathComponent("api/orders/mine")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        applyAuthenticationIfNeeded(to: &request, overrideToken: overrideToken)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OrderServiceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            if let message = decodeMessage(from: data), !message.isEmpty {
                throw OrderServiceError.message(message, code: httpResponse.statusCode)
            }
            throw OrderServiceError.statusCode(httpResponse.statusCode)
        }

        return try decoder.decode([Order].self, from: data)
    }

    func createCashOnDeliveryOrder(
        request payload: CreateCashOnDeliveryOrderRequest,
        token overrideToken: String? = nil
    ) async throws -> Order {
        let endpoint = baseURL.appendingPathComponent("api/orders")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        applyAuthenticationIfNeeded(to: &request, overrideToken: overrideToken)

        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OrderServiceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            if let message = decodeMessage(from: data), !message.isEmpty {
                throw OrderServiceError.message(message, code: httpResponse.statusCode)
            }
            throw OrderServiceError.statusCode(httpResponse.statusCode)
        }

        let decoded = try decoder.decode(CreateCashOnDeliveryOrderResponse.self, from: data)
        return decoded.order
    }

    private func applyAuthenticationIfNeeded(to request: inout URLRequest, overrideToken: String?) {
        let token = overrideToken ?? tokenProvider?.authToken
        guard let token, !token.isEmpty else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func decodeMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let response = try? decoder.decode(ErrorResponse.self, from: data) {
            if let message = response.message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return message
            }
        }

        if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
           let dictionary = jsonObject as? [String: Any],
           let message = dictionary["message"] as? String,
           !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }

        return nil
    }
}

extension OrderService {
    struct CreateCashOnDeliveryOrderRequest: Encodable {
        struct Item: Encodable {
            let productId: String
            let variantId: String?
            let sku: String?
            let quantity: Int
            let name: LocalizedText
            let color: String?
            let measure: String?

            init(
                productId: String,
                variantId: String? = nil,
                sku: String? = nil,
                quantity: Int,
                name: LocalizedText,
                color: String? = nil,
                measure: String? = nil
            ) {
                self.productId = productId
                self.variantId = variantId
                self.sku = sku
                self.quantity = quantity
                self.name = name
                self.color = color
                self.measure = measure
            }
        }

        let recaptchaToken: String
        let recaptchaAction: String
        let recaptchaMinScore: Double
        let address: String
        let notes: String?
        let paymentMethod: String
        let paymentStatus: String
        let status: String
        let items: [Item]

        init(
            recaptchaToken: String,
            recaptchaAction: String = AppConfiguration.recaptchaAction,
            recaptchaMinScore: Double = AppConfiguration.recaptchaMinScore,
            address: String,
            notes: String?,
            paymentMethod: String = "cod",
            paymentStatus: String = "unpaid",
            status: String = "waiting_confirmation",
            items: [Item]
        ) {
            self.recaptchaToken = recaptchaToken
            self.recaptchaAction = recaptchaAction
            self.recaptchaMinScore = recaptchaMinScore
            self.address = address
            self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.paymentMethod = paymentMethod
            self.paymentStatus = paymentStatus
            self.status = status
            self.items = items
        }
    }

    struct CreateCashOnDeliveryOrderResponse: Decodable {
        let order: Order

        init(from decoder: Decoder) throws {
            order = try Order(from: decoder)
        }
    }

    private struct ErrorResponse: Decodable {
        let message: String?
    }
}
