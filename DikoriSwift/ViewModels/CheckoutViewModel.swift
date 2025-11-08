import Foundation
import SwiftUI
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

@MainActor
final class CheckoutViewModel: ObservableObject {
    struct AlertItem: Identifiable {
        enum Kind {
            case success
            case failure
        }

        let id = UUID()
        let title: String
        let message: String
        let kind: Kind
    }

    @Published var shippingAddress: String = ""
    @Published var notes: String = ""
    @Published var selectedPaymentMethod: Order.PaymentMethod = .cashOnDelivery
    @Published private(set) var isSubmitting: Bool = false
    @Published private(set) var isRequestingPrivateToken: Bool = false
    @Published var inlineError: String?
    @Published var activeAlert: AlertItem?

    private let orderService: OrderService
    private let currencyFormatter: NumberFormatter
    private let serviceHost: String?

    #if canImport(AuthenticationServices)
    private let tokenRequester = PrivateAccessTokenRequester()
    #endif

    init(orderService: OrderService = .shared) {
        self.orderService = orderService
        self.currencyFormatter = OrderService.makeCurrencyFormatter()
        self.serviceHost = orderService.apiHost
    }

    var isLoading: Bool { isSubmitting || isRequestingPrivateToken }

    var paymentOptions: [Order.PaymentMethod] {
        [.cashOnDelivery, .card]
    }

    func canSubmit(cartManager: CartManager) -> Bool {
        guard !isLoading else { return false }
        guard !cartManager.isEmpty else { return false }
        return !shippingAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func submit(using cartManager: CartManager) async {
        inlineError = nil
        activeAlert = nil

        let trimmedAddress = shippingAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            inlineError = "الرجاء إدخال عنوان التوصيل"
            activeAlert = AlertItem(title: "عنوان غير صالح", message: "يرجى إدخال عنوان لتسليم الطلب.", kind: .failure)
            return
        }

        guard !cartManager.isEmpty else {
            inlineError = "السلة فارغة"
            activeAlert = AlertItem(title: "السلة فارغة", message: "أضف منتجات قبل إتمام الطلب.", kind: .failure)
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let privateToken = try await fetchPrivateAccessTokenIfNeeded()
            let payload = buildOrderPayload(using: cartManager, address: trimmedAddress, notes: notes)

            switch selectedPaymentMethod {
            case .cashOnDelivery:
                let order = try await orderService.createOrder(payload, privateToken: privateToken)
                cartManager.clear()
                notes = ""
                presentSuccessAlertForCashOrder(order: order)
            case .card:
                let prepared = try await orderService.prepareCardOrder(payload, privateToken: privateToken)
                cartManager.clear()
                notes = ""
                presentSuccessAlertForCard(prepared: prepared)
            case .unknown:
                throw CheckoutError.unsupportedPaymentMethod
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            inlineError = message
            activeAlert = AlertItem(title: "فشل الطلب", message: message, kind: .failure)
        }
    }

    private func buildOrderPayload(using cartManager: CartManager, address: String, notes: String) -> OrderService.OrderCreateRequest {
        OrderService.OrderCreateRequest(
            address: address,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            items: cartManager.checkoutLineItems.map { item in
                OrderService.OrderCreateRequest.LineItem(
                    productId: item.productId,
                    variantId: item.variantId,
                    quantity: item.quantity,
                    name: item.localizedName,
                    color: item.color,
                    measure: item.measure,
                    sku: item.sku,
                    image: item.image
                )
            },
            paymentMethod: selectedPaymentMethod,
            discount: cartManager.checkoutDiscount
        )
    }

    private func presentSuccessAlertForCashOrder(order: Order) {
        let total = currencyFormatter.string(from: order.total as NSNumber) ?? String(format: "%.2f", order.total)
        activeAlert = AlertItem(
            title: "تم إرسال الطلب",
            message: "رقم الطلب: \(order.id)\nالمبلغ الإجمالي: \(total)",
            kind: .success
        )
    }

    private func presentSuccessAlertForCard(prepared: OrderService.PreparedCardOrder) {
        let formattedTotal = currencyFormatter.string(from: prepared.total as NSNumber) ?? String(format: "%.2f", prepared.total)
        activeAlert = AlertItem(
            title: "تم تحضير الدفع",
            message: "رقم الطلب: \(prepared.id)\nالمبلغ المستحق: \(formattedTotal)",
            kind: .success
        )
    }

    private func fetchPrivateAccessTokenIfNeeded() async throws -> String? {
        #if os(iOS)
        guard #available(iOS 17.0, *) else { return nil }
        guard let host = serviceHost, !host.isEmpty else { return nil }

        isRequestingPrivateToken = true
        defer { isRequestingPrivateToken = false }

        #if canImport(AuthenticationServices)
        do {
            return try await tokenRequester.requestToken(for: host)
        } catch {
            throw error
        }
        #else
        return nil
        #endif
        #else
        return nil
        #endif
    }

    enum CheckoutError: LocalizedError {
        case unsupportedPaymentMethod

        var errorDescription: String? {
            switch self {
            case .unsupportedPaymentMethod:
                return "طريقة الدفع غير مدعومة"
            }
        }
    }
}

#if canImport(AuthenticationServices)
@available(iOS 17.0, *)
final class PrivateAccessTokenRequester: NSObject {
    func requestToken(for host: String) async throws -> String? {
        // Placeholder integration: Actual Private Access Token request implementation
        // should be added here once the server challenge and configuration are available.
        // Returning nil allows the checkout flow to continue without a token.
        _ = host
        return nil
    }
}
#endif
