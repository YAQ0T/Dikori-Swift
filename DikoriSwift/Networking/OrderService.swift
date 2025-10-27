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

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
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

    private func applyAuthenticationIfNeeded(to request: inout URLRequest, overrideToken: String?) {
        let token = overrideToken ?? tokenProvider?.authToken
        guard let token, !token.isEmpty else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}
