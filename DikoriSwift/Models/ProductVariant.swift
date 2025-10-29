import Foundation

struct ProductVariant: Identifiable, Codable, Hashable {
    struct ColorInfo: Codable, Hashable {
        let name: String
        let code: String?
        let images: [String]

        init(name: String = "", code: String? = nil, images: [String] = []) {
            self.name = name
            self.code = code
            self.images = images
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            let code = try container.decodeIfPresent(String.self, forKey: .code)
            let images = try container.decodeIfPresent([String].self, forKey: .images) ?? []
            self.init(name: name, code: code, images: images)
        }

        enum CodingKeys: String, CodingKey {
            case name
            case code
            case images
        }

        var primaryImageURL: URL? {
            images.compactMap { URL(string: $0) }.first
        }
    }

    struct PriceInfo: Codable, Hashable {
        struct DiscountInfo: Codable, Hashable {
            let type: String?
            let value: Double?
            let startAt: String?
            let endAt: String?
        }

        let currency: String?
        let amount: Double?
        let compareAt: Double?
        let discount: DiscountInfo?

        init(currency: String? = nil, amount: Double? = nil, compareAt: Double? = nil, discount: DiscountInfo? = nil) {
            self.currency = currency
            self.amount = amount
            self.compareAt = compareAt
            self.discount = discount
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let currency = try container.decodeIfPresent(String.self, forKey: .currency)
            let amount = try container.decodeIfPresent(Double.self, forKey: .amount)
            let compareAt = try container.decodeIfPresent(Double.self, forKey: .compareAt)
            let discount = try container.decodeIfPresent(DiscountInfo.self, forKey: .discount)
            self.init(currency: currency, amount: amount, compareAt: compareAt, discount: discount)
        }

        var effectiveAmount: Double? {
            amount
        }

        private enum CodingKeys: String, CodingKey {
            case currency
            case amount
            case compareAt
            case discount
        }
    }

    struct StockInfo: Codable, Hashable {
        let inStock: Int?
        let sku: String?

        init(inStock: Int? = nil, sku: String? = nil) {
            self.inStock = inStock
            self.sku = sku
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let inStock = try container.decodeIfPresent(Int.self, forKey: .inStock)
            let sku = try container.decodeIfPresent(String.self, forKey: .sku)
            self.init(inStock: inStock, sku: sku)
        }

        private enum CodingKeys: String, CodingKey {
            case inStock
            case sku
        }
    }

    let id: String
    let productID: String
    let measure: String
    let measureUnit: String
    let measureSlug: String?
    let color: ColorInfo
    let colorSlug: String?
    let price: PriceInfo
    let stock: StockInfo?
    let tags: [String]
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case productID = "product"
        case measure
        case measureUnit
        case measureSlug
        case color
        case colorSlug
        case price
        case stock
        case tags
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let id = try container.decode(String.self, forKey: .id)
        let productID = try container.decode(String.self, forKey: .productID)
        let measure = try container.decodeIfPresent(String.self, forKey: .measure) ?? ""
        let measureUnit = try container.decodeIfPresent(String.self, forKey: .measureUnit) ?? ""
        let measureSlug = try container.decodeIfPresent(String.self, forKey: .measureSlug)
        let color = try container.decodeIfPresent(ColorInfo.self, forKey: .color) ?? ColorInfo()
        let colorSlug = try container.decodeIfPresent(String.self, forKey: .colorSlug)
        let price = try container.decodeIfPresent(PriceInfo.self, forKey: .price) ?? PriceInfo()
        let stock = try container.decodeIfPresent(StockInfo.self, forKey: .stock)
        let tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        let createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        let updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)

        self.init(
            id: id,
            productID: productID,
            measure: measure,
            measureUnit: measureUnit,
            measureSlug: measureSlug,
            color: color,
            colorSlug: colorSlug,
            price: price,
            stock: stock,
            tags: tags,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    init(
        id: String,
        productID: String,
        measure: String,
        measureUnit: String = "",
        measureSlug: String? = nil,
        color: ColorInfo,
        colorSlug: String? = nil,
        price: PriceInfo,
        stock: StockInfo? = nil,
        tags: [String] = [],
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.productID = productID
        self.measure = measure
        self.measureUnit = measureUnit
        self.measureSlug = measureSlug
        self.color = color
        self.colorSlug = colorSlug
        self.price = price
        self.stock = stock
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayMeasure: String {
        if measureUnit.isEmpty {
            return measure
        }
        return "\(measure) \(measureUnit)".trimmingCharacters(in: .whitespaces)
    }

    var colorName: String { color.name }

    var primaryImageURL: URL? {
        color.primaryImageURL
    }
}
