import Foundation

enum OrdersManagerError: LocalizedError {
    case notAuthenticated
    case emptyItems
    case missingAddress

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "يجب تسجيل الدخول لإجراء هذا الطلب"
        case .emptyItems:
            return "لا يمكن إنشاء طلب بدون عناصر"
        case .missingAddress:
            return "الرجاء إدخال عنوان التوصيل"
        }
    }
}

@MainActor
final class OrdersManager: ObservableObject {
    @Published private(set) var orders: [Order] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    var authToken: String? {
        didSet {
            let trimmed = authToken?.trimmingCharacters(in: .whitespacesAndNewlines)
            let previous = oldValue?.trimmingCharacters(in: .whitespacesAndNewlines)

            guard trimmed != previous else { return }

            if let trimmed, !trimmed.isEmpty {
                Task { await loadOrders(force: true) }
            } else {
                if authToken == nil {
                    orders = []
                }
                errorMessage = nil
                isLoading = false
            }
        }
    }

    private let service: OrderService

    init(service: OrderService = .shared) {
        self.service = service
    }

    func loadOrders(force: Bool = false) async {
        if !force && !orders.isEmpty { return }
        guard let token = authToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await service.fetchMyOrders(token: token)
            orders = fetched
        } catch {
            if orders.isEmpty {
                orders = Order.samples()
            }
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        guard let token = authToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        do {
            orders = try await service.fetchMyOrders(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func createCashOnDeliveryOrder(
        address: String,
        notes: String?,
        items: [OrderService.CreateCashOnDeliveryOrderRequest.Item],
        recaptchaToken: String
    ) async throws -> Order {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            throw OrdersManagerError.missingAddress
        }

        guard !items.isEmpty else {
            throw OrdersManagerError.emptyItems
        }

        guard let token = authToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            throw OrdersManagerError.notAuthenticated
        }

        let payload = OrderService.CreateCashOnDeliveryOrderRequest(
            recaptchaToken: recaptchaToken,
            address: trimmedAddress,
            notes: notes,
            items: items
        )

        do {
            let order = try await service.createCashOnDeliveryOrder(request: payload, token: token)
            errorMessage = nil

            if let refreshed = try? await service.fetchMyOrders(token: token) {
                orders = refreshed
            }

            return order
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

#if DEBUG
extension OrdersManager {
    static func preview(orders: [Order] = Order.samples()) -> OrdersManager {
        let manager = OrdersManager(service: OrderService())
        manager.orders = orders
        manager.isLoading = false
        manager.errorMessage = nil
        return manager
    }
}
#endif
