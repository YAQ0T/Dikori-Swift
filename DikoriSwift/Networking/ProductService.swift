import Foundation

enum ProductServiceError: LocalizedError {
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

struct ProductQuery {
    var page: Int?
    var limit: Int?
    var mainCategory: String?
    var subCategory: String?
    var search: String?

    func queryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let page { items.append(URLQueryItem(name: "page", value: String(page))) }
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let mainCategory, !mainCategory.isEmpty {
            items.append(URLQueryItem(name: "mainCategory", value: mainCategory))
        }
        if let subCategory, !subCategory.isEmpty {
            items.append(URLQueryItem(name: "subCategory", value: subCategory))
        }
        if let search, !search.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(URLQueryItem(name: "q", value: search))
        }
        return items
    }
}

final class ProductService {
    static let shared = ProductService()

    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder

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

    func fetchProducts(query: ProductQuery = ProductQuery()) async throws -> [Product] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/products"), resolvingAgainstBaseURL: false)
        components?.queryItems = query.queryItems()

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProductServiceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw ProductServiceError.statusCode(httpResponse.statusCode)
        }

        return try decoder.decode([Product].self, from: data)
    }
}
