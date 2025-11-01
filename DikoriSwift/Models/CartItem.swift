import Foundation

struct CartItem: Identifiable, Codable, Hashable {
    struct MatchingKey: Hashable, Codable {
        let productID: String
        let variantID: String?
        let colorName: String?
        let measure: String?

        init(productID: String, variantID: String?, colorName: String?, measure: String?) {
            self.productID = productID
            self.variantID = variantID
            self.colorName = colorName?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.measure = measure?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    let id: UUID
    let productID: String
    let variantID: String?
    let title: String
    let subtitle: String
    let imageURL: URL?
    let colorName: String?
    let measure: String?
    let productName: LocalizedText
    let sku: String?
    var unitPrice: Double
    var quantity: Int
    let matchingKey: MatchingKey

    init(
        id: UUID = UUID(),
        productID: String,
        variantID: String? = nil,
        title: String,
        subtitle: String,
        imageURL: URL? = nil,
        colorName: String? = nil,
        measure: String? = nil,
        productName: LocalizedText = LocalizedText(),
        sku: String? = nil,
        unitPrice: Double,
        quantity: Int,
        matchingKey: MatchingKey
    ) {
        self.id = id
        self.productID = productID
        self.variantID = variantID
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.colorName = colorName
        self.measure = measure
        self.productName = productName
        let trimmedSKU = sku?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sku = trimmedSKU?.isEmpty == true ? nil : trimmedSKU
        self.unitPrice = unitPrice
        self.quantity = max(1, quantity)
        self.matchingKey = matchingKey
    }

    init(product: Product, variant: ProductVariant?, quantity: Int, unitPrice: Double) {
        let key = MatchingKey(
            productID: product.id,
            variantID: variant?.id,
            colorName: variant?.colorName,
            measure: variant?.displayMeasure
        )

        self.init(
            productID: product.id,
            variantID: variant?.id,
            title: product.displayName,
            subtitle: product.secondaryText,
            imageURL: variant?.primaryImageURL ?? product.primaryImageURL,
            colorName: variant?.colorName,
            measure: variant?.displayMeasure,
            productName: product.name,
            sku: variant?.stock?.sku,
            unitPrice: unitPrice,
            quantity: quantity,
            matchingKey: key
        )
    }

    var optionsSummary: String? {
        let components = [colorName, measure]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return components.isEmpty ? nil : components.joined(separator: " • ")
    }

    var totalPrice: Double { unitPrice * Double(quantity) }
}

extension CartItem.MatchingKey {
    func matches(productID: String, variantID: String?, colorName: String?, measure: String?) -> Bool {
        let normalizedColor = colorName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedMeasure = measure?.trimmingCharacters(in: .whitespacesAndNewlines)
        return self.productID == productID &&
            self.variantID == variantID &&
            self.colorName == normalizedColor &&
            self.measure == normalizedMeasure
    }
}

extension CartItem {
    func asOrderRequestItem() -> OrderService.CashOnDeliveryOrderRequest.Item {
        let sanitizedName: LocalizedText? = {
            let trimmedArabic = productName.ar.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedHebrew = productName.he.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedArabic.isEmpty && trimmedHebrew.isEmpty {
                return nil
            }
            return LocalizedText(ar: trimmedArabic, he: trimmedHebrew)
        }()

        return OrderService.CashOnDeliveryOrderRequest.Item(
            productId: productID,
            variantId: variantID,
            quantity: quantity,
            name: sanitizedName,
            color: colorName,
            measure: measure,
            sku: sku,
            image: imageURL?.absoluteString
        )
    }
}
