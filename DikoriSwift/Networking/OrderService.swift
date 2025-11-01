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
        items: [CashOnDeliveryOrderItem],
        token overrideToken: String? = nil
    ) async throws -> Order {
        let endpoint = baseURL.appendingPathComponent("api/orders")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        applyAuthenticationIfNeeded(to: &request, overrideToken: overrideToken)

        let body = CashOnDeliveryOrderRequest(
            address: address,
            notes: notes,
            items: items
        )
        request.httpBody = try encoder.encode(body)

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

extension OrderService {
    struct CashOnDeliveryOrderItem: Encodable {
        let productId: String
        let variantId: String?
        let name: LocalizedText?
        let quantity: Int
        let color: String?
        let measure: String?
        let sku: String?
        let image: String?

        init(
            productId: String,
            variantId: String? = nil,
            name: LocalizedText? = nil,
            quantity: Int,
            color: String? = nil,
            measure: String? = nil,
            sku: String? = nil,
            image: String? = nil
        ) {
            self.productId = productId
            let trimmedVariantId = variantId?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.variantId = trimmedVariantId?.isEmpty == true ? nil : trimmedVariantId
            self.name = name
            self.quantity = max(1, quantity)
            let trimmedColor = color?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.color = trimmedColor?.isEmpty == true ? nil : trimmedColor
            let trimmedMeasure = measure?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.measure = trimmedMeasure?.isEmpty == true ? nil : trimmedMeasure
            let trimmedSKU = sku?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.sku = trimmedSKU?.isEmpty == true ? nil : trimmedSKU
            if let image, !image.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.image = image
            } else {
                self.image = nil
            }
        }
    }

    private struct CashOnDeliveryOrderRequest: Encodable {
        let address: String
        let notes: String?
        let items: [CashOnDeliveryOrderItem]
        let paymentMethod: String = "cod"

        init(address: String, notes: String?, items: [CashOnDeliveryOrderItem]) {
            self.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            self.items = items
        }

        enum CodingKeys: String, CodingKey {
            case address
            case notes
            case items
            case paymentMethod
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
}
