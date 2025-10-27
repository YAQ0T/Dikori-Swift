import Foundation

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
