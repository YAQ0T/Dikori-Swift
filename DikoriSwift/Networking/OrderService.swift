import Foundation

enum OrderServiceError: LocalizedError {
    case invalidResponse
    case statusCode(Int)
    case server(message: String?, statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "استجابة غير صالحة من الخادم"
        case .statusCode(let code):
            return "الخادم أعاد رمز الخطأ \(code)"
        case .server(let message, let statusCode):
            if let message, !message.isEmpty {
                return message
            } else {
                return "الخادم أعاد رمز الخطأ \(statusCode)"
            }
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

    @discardableResult
    func createCODOrder(address: String,
                        notes: String?,
                        items: [CartItem],
                        recaptchaToken: String,
                        recaptchaAction: String,
                        recaptchaMinScore: Double? = nil,
                        overrideToken: String? = nil) async throws -> Order {
        let endpoint = baseURL.appendingPathComponent("api/orders")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        applyAuthenticationIfNeeded(to: &request, overrideToken: overrideToken)

        let body = CreateOrderRequestBody(
            address: address,
            notes: notes,
            items: items.map(CreateOrderRequestBody.Item.init(cartItem:)),
            paymentMethod: "cod",
            recaptchaToken: recaptchaToken,
            recaptchaAction: recaptchaAction,
            recaptchaMinScore: recaptchaMinScore
        )

        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OrderServiceError.invalidResponse
        }

        if 200..<300 ~= httpResponse.statusCode {
            return try decoder.decode(Order.self, from: data)
        }

        if let errorResponse = try? decoder.decode(ServerErrorResponse.self, from: data) {
            throw OrderServiceError.server(message: errorResponse.message, statusCode: httpResponse.statusCode)
        }

        throw OrderServiceError.server(message: nil, statusCode: httpResponse.statusCode)
    }

    private func applyAuthenticationIfNeeded(to request: inout URLRequest, overrideToken: String?) {
        let token = overrideToken ?? tokenProvider?.authToken
        guard let token, !token.isEmpty else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}

private struct CreateOrderRequestBody: Encodable {
    struct Item: Encodable {
        let productId: String
        let variantId: String?
        let name: LocalizedText
        let quantity: Int
        let color: String?
        let measure: String?
        let sku: String?
        let image: String?

        init(cartItem: CartItem) {
            self.productId = cartItem.productID
            self.variantId = cartItem.variantID
            self.name = LocalizedText(ar: cartItem.title, he: "")
            self.quantity = max(1, cartItem.quantity)

            let trimmedColor = cartItem.colorName?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.color = trimmedColor?.isEmpty == false ? trimmedColor : nil

            let trimmedMeasure = cartItem.measure?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.measure = trimmedMeasure?.isEmpty == false ? trimmedMeasure : nil

            self.sku = nil
            self.image = cartItem.imageURL?.absoluteString
        }
    }

    let address: String
    let notes: String?
    let items: [Item]
    let paymentMethod: String
    let recaptchaToken: String
    let recaptchaAction: String
    let recaptchaMinScore: Double?
}

private struct ServerErrorResponse: Decodable {
    let message: String?
}
