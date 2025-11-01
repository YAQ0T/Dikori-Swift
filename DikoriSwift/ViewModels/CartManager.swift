import Foundation
import SwiftUI

@MainActor
final class CartManager: ObservableObject {
    @Published private(set) var items: [CartItem]

    init(items: [CartItem] = []) {
        self.items = items
    }

    var isEmpty: Bool { items.isEmpty }

    var totalItems: Int {
        items.reduce(0) { $0 + $1.quantity }
    }

    var totalPrice: Double {
        items.reduce(0) { $0 + $1.totalPrice }
    }

    var formattedTotalPrice: String {
        formattedPrice(totalPrice)
    }

    func add(product: Product, variant: ProductVariant?, quantity: Int, unitPrice: Double) {
        guard quantity > 0 else { return }

        let key = CartItem.MatchingKey(
            productID: product.id,
            variantID: variant?.id,
            colorName: variant?.colorName,
            measure: variant?.displayMeasure
        )

        if let index = items.firstIndex(where: { $0.matchingKey == key }) {
            items[index].quantity += quantity
            items[index].unitPrice = unitPrice
        } else {
            let item = CartItem(product: product, variant: variant, quantity: quantity, unitPrice: unitPrice)
            items.append(item)
        }
    }

    func updateQuantity(for itemID: CartItem.ID, to newQuantity: Int) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].quantity = max(1, newQuantity)
    }

    func increaseQuantity(for itemID: CartItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].quantity += 1
    }

    func decreaseQuantity(for itemID: CartItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].quantity = max(1, items[index].quantity - 1)
    }

    func remove(itemID: CartItem.ID) {
        items.removeAll { $0.id == itemID }
    }

    func removeItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    func clear() {
        items.removeAll()
    }

    func formattedPrice(_ amount: Double) -> String {
        Self.currencyFormatter.string(from: amount as NSNumber) ?? String(format: "%.2f ILS", amount)
    }

    static func preview() -> CartManager {
        let sampleItems: [CartItem] = [
            CartItem(
                productID: "demo-1",
                title: "مثقاب كهربائي احترافي",
                subtitle: "معدات كهربائية",
                imageURL: URL(string: "https://i.imgur.com/KKPpSNy.png"),
                colorName: "أزرق",
                measure: "١٢ ملم",
                productName: LocalizedText(ar: "مثقاب كهربائي احترافي", he: "מקדחה חשמלית מקצועית"),
                sku: "DRILL-001",
                unitPrice: 349.0,
                quantity: 2,
                matchingKey: CartItem.MatchingKey(productID: "demo-1", variantID: nil, colorName: "أزرق", measure: "١٢ ملم")
            ),
            CartItem(
                productID: "demo-2",
                title: "مجموعة أدوات النجارة",
                subtitle: "عدة كاملة",
                imageURL: URL(string: "https://i.imgur.com/KKPpSNy.png"),
                colorName: nil,
                measure: nil,
                productName: LocalizedText(ar: "مجموعة أدوات النجارة", he: "ערכת כלים לנגרות"),
                sku: "WOOD-SET-002",
                unitPrice: 189.5,
                quantity: 1,
                matchingKey: CartItem.MatchingKey(productID: "demo-2", variantID: nil, colorName: nil, measure: nil)
            )
        ]

        return CartManager(items: sampleItems)
    }

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "ILS"
        formatter.locale = Locale(identifier: "ar")
        return formatter
    }()
}
