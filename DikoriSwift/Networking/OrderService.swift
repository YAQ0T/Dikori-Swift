import Foundation

enum OrderServiceError: LocalizedError {
    case invalidResponse
    case statusCode(Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "استجابة غير صالحة من الخادم"
        case .statusCode(let code, let message):
            if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return message
            }
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
        self.encoder = OrderService.makeEncoder()
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        return encoder
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
            throw OrderServiceError.statusCode(httpResponse.statusCode, message: nil)
        }

        return try decoder.decode([Order].self, from: data)
    }

    func createCashOnDeliveryOrder(
        _ requestBody: CashOnDeliveryOrderRequest,
        token overrideToken: String? = nil
    ) async throws -> Order {
        let endpoint = baseURL.appendingPathComponent("api/orders")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        applyAuthenticationIfNeeded(to: &request, overrideToken: overrideToken)

        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OrderServiceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let serverMessage: String? = {
                if let decoded = try? decoder.decode(ServerErrorResponse.self, from: data) {
                    return decoded.message
                }
                if let rawString = String(data: data, encoding: .utf8) {
                    let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : trimmed
                }
                return nil
            }()
            throw OrderServiceError.statusCode(httpResponse.statusCode, message: serverMessage)
        }

        return try decoder.decode(Order.self, from: data)
    }

    private func applyAuthenticationIfNeeded(to request: inout URLRequest, overrideToken: String?) {
        let token = overrideToken ?? tokenProvider?.authToken
        guard let token, !token.isEmpty else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}

extension OrderService {
    struct CashOnDeliveryOrderRequest: Encodable {
        struct Item: Encodable {
            let productId: String
            let variantId: String?
            let quantity: Int
            let name: LocalizedText?
            let color: String?
            let measure: String?
            let sku: String?
            let image: String?

            init(
                productId: String,
                variantId: String? = nil,
                quantity: Int,
                name: LocalizedText? = nil,
                color: String? = nil,
                measure: String? = nil,
                sku: String? = nil,
                image: String? = nil
            ) {
                self.productId = productId
                self.variantId = Item.sanitized(variantId)
                self.quantity = max(1, quantity)
                self.name = Item.sanitized(name)
                self.color = Item.sanitized(color)
                self.measure = Item.sanitized(measure)
                self.sku = Item.sanitized(sku)
                self.image = Item.sanitized(image)
            }

            private static func sanitized(_ value: String?) -> String? {
                guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                    return nil
                }
                return trimmed
            }

            private static func sanitized(_ value: LocalizedText?) -> LocalizedText? {
                guard let value else { return nil }
                let trimmedArabic = value.ar.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedHebrew = value.he.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedArabic.isEmpty && trimmedHebrew.isEmpty {
                    return nil
                }
                return LocalizedText(ar: trimmedArabic, he: trimmedHebrew)
            }
        }

        let address: String
        let notes: String?
        let paymentMethod: String
        let items: [Item]

        init(
            address: String,
            notes: String? = nil,
            items: [Item]
        ) {
            self.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            self.paymentMethod = "cod"
            self.items = items
        }

        enum CodingKeys: String, CodingKey {
            case address
            case notes
            case paymentMethod
            case items
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(address, forKey: .address)
            try container.encode(items, forKey: .items)
            try container.encode(paymentMethod, forKey: .paymentMethod)
            if let notes {
                try container.encode(notes, forKey: .notes)
            }
        }
    }

    fileprivate struct ServerErrorResponse: Decodable {
        let message: String
    }
}
