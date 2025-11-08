import Foundation

enum OrderServiceError: LocalizedError {
    case invalidResponse
    case statusCode(Int)
    case apiMessage(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "استجابة غير صالحة من الخادم"
        case .statusCode(let code):
            return "الخادم أعاد رمز الخطأ \(code)"
        case .apiMessage(let message):
            return message
        }
    }
}

final class OrderService {
    static let shared = OrderService()

    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
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
    }

    var apiHost: String? { baseURL.host }

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

    func createOrder(
        _ payload: OrderCreateRequest,
        overrideToken: String? = nil,
        privateToken: String? = nil
    ) async throws -> Order {
        let endpoint = baseURL.appendingPathComponent("api/orders")
        return try await performOrderRequest(
            url: endpoint,
            payload: payload,
            overrideToken: overrideToken,
            privateToken: privateToken
        )
    }

    func prepareCardOrder(
        _ payload: OrderCreateRequest,
        overrideToken: String? = nil,
        privateToken: String? = nil
    ) async throws -> PreparedCardOrder {
        let endpoint = baseURL.appendingPathComponent("api/orders/prepare-card")
        let data = try await performDataRequest(
            url: endpoint,
            payload: payload,
            overrideToken: overrideToken,
            privateToken: privateToken
        )

        guard let httpResponse = data.response as? HTTPURLResponse else {
            throw OrderServiceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            if let message = decodeAPIError(from: data.data) {
                throw OrderServiceError.apiMessage(message)
            }
            throw OrderServiceError.statusCode(httpResponse.statusCode)
        }

        let decoded = try decoder.decode(PreparedCardOrder.self, from: data.data)
        return decoded
    }

    private func applyAuthenticationIfNeeded(to request: inout URLRequest, overrideToken: String?) {
        let token = overrideToken ?? tokenProvider?.authToken
        guard let token, !token.isEmpty else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func performOrderRequest(
        url: URL,
        payload: OrderCreateRequest,
        overrideToken: String?,
        privateToken: String?
    ) async throws -> Order {
        let data = try await performDataRequest(
            url: url,
            payload: payload,
            overrideToken: overrideToken,
            privateToken: privateToken
        )

        guard let httpResponse = data.response as? HTTPURLResponse else {
            throw OrderServiceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            if let message = decodeAPIError(from: data.data) {
                throw OrderServiceError.apiMessage(message)
            }
            throw OrderServiceError.statusCode(httpResponse.statusCode)
        }

        return try decoder.decode(Order.self, from: data.data)
    }

    private func performDataRequest(
        url: URL,
        payload: OrderCreateRequest,
        overrideToken: String?,
        privateToken: String?
    ) async throws -> (data: Data, response: URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let privateToken, !privateToken.isEmpty {
            request.setValue(privateToken, forHTTPHeaderField: "PrivateToken")
        }

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        applyAuthenticationIfNeeded(to: &request, overrideToken: overrideToken)

        return try await session.data(for: request)
    }

    private func decodeAPIError(from data: Data) -> String? {
        let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
        return apiError?.message ?? apiError?.error
    }

    static func makeCurrencyFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "ILS"
        formatter.locale = Locale(identifier: "ar")
        return formatter
    }
}

extension OrderService {
    struct OrderCreateRequest: Encodable {
        struct LineItem: Encodable {
            let productId: String
            let variantId: String?
            let quantity: Int
            let name: [String: String]
            let color: String?
            let measure: String?
            let sku: String?
            let image: String?
        }

        let address: String
        let notes: String?
        let items: [LineItem]
        let paymentMethod: Order.PaymentMethod
        let discount: CartManager.CheckoutDiscount?

        private enum CodingKeys: String, CodingKey {
            case address
            case notes
            case items
            case paymentMethod
            case discount
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(address, forKey: .address)
            try container.encodeIfPresent(notes, forKey: .notes)
            try container.encode(items, forKey: .items)
            try container.encode(paymentMethod, forKey: .paymentMethod)
            try container.encodeIfPresent(discount, forKey: .discount)
        }
    }

    struct PreparedCardOrder: Decodable {
        let id: String
        let total: Double

        private enum CodingKeys: String, CodingKey {
            case id = "_id"
            case total
        }
    }

    private struct APIErrorResponse: Decodable {
        let message: String?
        let error: String?
    }
}
