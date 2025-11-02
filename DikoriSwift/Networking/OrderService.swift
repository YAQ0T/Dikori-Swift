import Foundation

enum OrderServiceError: LocalizedError {
    case invalidResponse
    case statusCode(Int)
    case message(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "استجابة غير صالحة من الخادم"
        case .statusCode(let code):
            return "الخادم أعاد رمز الخطأ \(code)"
        case .message(let text):
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

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        self.encoder = encoder
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
            throw OrderServiceError.statusCode(httpResponse.statusCode)
        }

        return try decoder.decode([Order].self, from: data)
    }

    func createCashOnDeliveryOrder(address rawAddress: String,
                                   notes rawNotes: String?,
                                   items: [CartItem],
                                   recaptchaToken rawToken: String,
                                   recaptchaAction: String = "checkout",
                                   overrideToken: String? = nil) async throws -> Order {
        let address = rawAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = rawNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let action = recaptchaAction.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedAction = action.isEmpty ? "checkout" : action

        guard !address.isEmpty else {
            throw OrderServiceError.message("الرجاء إدخال عنوان التوصيل")
        }
        guard !items.isEmpty else {
            throw OrderServiceError.message("السلة فارغة")
        }
        guard !token.isEmpty else {
            throw OrderServiceError.message("رمز reCAPTCHA غير صالح")
        }

        let endpoint = baseURL.appendingPathComponent("api/orders")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        applyAuthenticationIfNeeded(to: &request, overrideToken: overrideToken)

        let payload = CashOnDeliveryOrderRequest(
            address: address,
            notes: notes?.isEmpty == true ? nil : notes,
            items: items.map(CashOnDeliveryOrderRequest.Item.init),
            recaptchaToken: token,
            recaptchaAction: resolvedAction
        )

        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OrderServiceError.invalidResponse
        }

        if 200..<300 ~= httpResponse.statusCode {
            return try decoder.decode(Order.self, from: data)
        } else {
            if let serverError = try? decoder.decode(ServerMessageResponse.self, from: data) {
                if let message = serverError.message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw OrderServiceError.message(message)
                }
                if let error = serverError.error, !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw OrderServiceError.message(error)
                }
            }
            throw OrderServiceError.statusCode(httpResponse.statusCode)
        }
    }

    private func applyAuthenticationIfNeeded(to request: inout URLRequest, overrideToken: String?) {
        let token = overrideToken ?? tokenProvider?.authToken
        guard let token, !token.isEmpty else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}

private struct ServerMessageResponse: Decodable {
    let message: String?
    let error: String?
}

private struct CashOnDeliveryOrderRequest: Encodable {
    struct Item: Encodable {
        let productId: String
        let variantId: String?
        let quantity: Int
        let name: String
        let measure: String?
        let color: String?
        let sku: String?
        let image: String?

        init(cartItem: CartItem) {
            self.productId = cartItem.productID
            self.variantId = cartItem.variantID
            self.quantity = max(1, cartItem.quantity)
            self.name = cartItem.title
            self.measure = cartItem.measure?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.color = cartItem.colorName?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.sku = nil
            self.image = cartItem.imageURL?.absoluteString
        }
    }

    let address: String
    let notes: String?
    let paymentMethod: String = "cod"
    let items: [Item]
    let recaptchaToken: String
    let recaptchaAction: String
}
