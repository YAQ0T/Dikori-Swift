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

    func fetchProducts(query: ProductQuery = ProductQuery()) async throws -> [Product] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/products"), resolvingAgainstBaseURL: false)
        components?.queryItems = query.queryItems()

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuthenticationIfNeeded(to: &request)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProductServiceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw ProductServiceError.statusCode(httpResponse.statusCode)
        }

        return try decoder.decode([Product].self, from: data)
    }

    func fetchCategoryGroups(limit: Int = 500) async throws -> [ProductCategoryGroup] {
        var query = ProductQuery()
        query.limit = limit

        let products = try await fetchProducts(query: query)
        let grouped = Dictionary(grouping: products) { product in
            product.mainCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return grouped
            .map { key, products in
                let subCategories = Array(
                    Set(
                        products
                            .map { $0.subCategory.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                    )
                )
                return ProductCategoryGroup(
                    mainCategory: key,
                    subCategories: subCategories
                )
            }
            .sorted { lhs, rhs in
                lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
    }

    struct ProductDetailsResponse: Decodable {
        let product: Product
        let variants: [ProductVariant]

        private enum CodingKeys: String, CodingKey {
            case variants
        }

        init(product: Product, variants: [ProductVariant] = []) {
            self.product = product
            self.variants = variants
        }

        init(from decoder: Decoder) throws {
            let product = try Product(from: decoder)
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let variants = try container.decodeIfPresent([ProductVariant].self, forKey: .variants) ?? []
            self.init(product: product, variants: variants)
        }
    }

    func fetchProduct(id: String, withVariants: Bool = false) async throws -> ProductDetailsResponse {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/products/\(id)"),
            resolvingAgainstBaseURL: false
        )

        if withVariants {
            components?.queryItems = [URLQueryItem(name: "withVariants", value: "1")]
        }

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuthenticationIfNeeded(to: &request)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProductServiceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw ProductServiceError.statusCode(httpResponse.statusCode)
        }

        return try decoder.decode(ProductDetailsResponse.self, from: data)
    }

    private func applyAuthenticationIfNeeded(to request: inout URLRequest) {
        guard let token = tokenProvider?.authToken, !token.isEmpty else {
            return
        }

        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}
