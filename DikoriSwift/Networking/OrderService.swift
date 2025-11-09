import Foundation

enum OrderServiceError: LocalizedError {
    case invalidResponse
    case statusCode(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "استجابة غير صالحة من الخادم"
        case .statusCode(let code):
            return "الخادم أعاد رمز الخطأ \(code)"
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
            throw OrderServiceError.statusCode(httpResponse.statusCode)
        }

        return try decoder.decode([Order].self, from: data)
    }

    func createCashOnDeliveryOrder(
        address: String,
        notes: String?,
        items: [CartItem],
        token overrideToken: String? = nil
    ) async throws -> Order {
        let endpoint = baseURL.appendingPathComponent("api/orders")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ios-app", forHTTPHeaderField: "X-Dikori-Client")

        applyAuthenticationIfNeeded(to: &request, overrideToken: overrideToken)

        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            throw OrderServiceError.invalidResponse
        }

        let payload = CashOnDeliveryOrderRequest(
            address: trimmedAddress,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).flatMap { $0.isEmpty ? nil : $0 },
            items: items.map { CashOnDeliveryOrderRequest.Item(from: $0) }
        )

        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OrderServiceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw OrderServiceError.statusCode(httpResponse.statusCode)
        }

        return try decoder.decode(Order.self, from: data)
    }

    private func applyAuthenticationIfNeeded(to request: inout URLRequest, overrideToken: String?) {
        let token = overrideToken ?? tokenProvider?.authToken
        guard let token, !token.isEmpty else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}

private extension OrderService {
    struct CashOnDeliveryOrderRequest: Encodable {
        struct Item: Encodable {
            let productId: String
            let variantId: String?
            let name: LocalizedText
            let quantity: Int
            let color: String?
            let measure: String?
            let sku: String?
            let image: String?

            init(from item: CartItem) {
                self.productId = item.productID
                self.variantId = item.variantID
                self.name = LocalizedText(ar: item.title, he: "")
                self.quantity = max(1, item.quantity)
                self.color = item.colorName?.trimmingCharacters(in: .whitespacesAndNewlines)
                self.measure = item.measure?.trimmingCharacters(in: .whitespacesAndNewlines)
                self.sku = nil
                self.image = item.imageURL?.absoluteString
            }
        }

        let address: String
        let notes: String?
        let items: [Item]
        let paymentMethod: String = "cod"
    }
}
