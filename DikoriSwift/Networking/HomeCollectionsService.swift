import Foundation

struct HomeCollectionsResponse: Decodable {
    let recommended: [Product]
    let newArrivals: [Product]
}

enum HomeCollectionsServiceError: LocalizedError {
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

final class HomeCollectionsService {
    static let shared = HomeCollectionsService()

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
        decoder.keyDecodingStrategy = .useDefaultKeys
        self.decoder = decoder
    }

    func fetchCollections() async throws -> HomeCollectionsResponse {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/home-collections"),
            resolvingAgainstBaseURL: false
        )

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuthenticationIfNeeded(to: &request)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HomeCollectionsServiceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw HomeCollectionsServiceError.statusCode(httpResponse.statusCode)
        }

        return try decoder.decode(HomeCollectionsResponse.self, from: data)
    }

    private func applyAuthenticationIfNeeded(to request: inout URLRequest) {
        guard let token = tokenProvider?.authToken, !token.isEmpty else {
            return
        }

        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}
