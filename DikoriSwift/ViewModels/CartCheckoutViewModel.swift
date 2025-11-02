import Foundation

@MainActor
final class CartCheckoutViewModel: ObservableObject {
    @Published var address: String = ""
    @Published var notes: String = ""
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String?

    private let orderService: OrderService
    private let recaptchaManager: RecaptchaManager

    init(
        orderService: OrderService = .shared,
        recaptchaManager: RecaptchaManager = .shared
    ) {
        self.orderService = orderService
        self.recaptchaManager = recaptchaManager
    }

    func submit(cart: CartManager) async -> Bool {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAddress.isEmpty else {
            errorMessage = "الرجاء إدخال عنوان التوصيل"
            return false
        }

        guard !cart.isEmpty else {
            errorMessage = "لا توجد عناصر في السلة لإتمام الطلب"
            return false
        }

        isSubmitting = true
        errorMessage = nil

        defer { isSubmitting = false }

        do {
            let token = try await recaptchaManager.fetchToken(action: "checkout")
            let payloadItems = cart.items.map { item in
                CheckoutItemPayload(
                    productId: item.productID,
                    variantId: item.variantID,
                    quantity: item.quantity,
                    name: item.title,
                    color: item.colorName,
                    measure: item.measure,
                    sku: nil,
                    image: item.imageURL?.absoluteString
                )
            }

            _ = try await orderService.createCashOnDeliveryOrder(
                address: trimmedAddress,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                items: payloadItems,
                recaptchaToken: token
            )

            cart.clear()
            address = ""
            notes = ""
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
