import Foundation

@MainActor
final class NotificationsManager: ObservableObject {
    @Published private(set) var notifications: [AppNotification] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    var authToken: String? {
        didSet {
            if authToken != oldValue {
                Task { await loadNotifications(force: true) }
            }
        }
    }

    private let service: NotificationService

    init(service: NotificationService = .shared) {
        self.service = service
    }

    func loadNotifications(force: Bool = false) async {
        if !force && !notifications.isEmpty {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await service.fetchMyNotifications(token: authToken)
            notifications = fetched
        } catch {
            if notifications.isEmpty {
                notifications = AppNotification.samples()
            }
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            notifications = try await service.fetchMyNotifications(token: authToken)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func markAsRead(_ notification: AppNotification) async {
        guard !notification.isRead else { return }

        do {
            let updated = try await service.markNotificationAsRead(id: notification.id, token: authToken)
            if let index = notifications.firstIndex(where: { $0.id == updated.id }) {
                notifications[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(_ notification: AppNotification) {
        notifications.removeAll { $0.id == notification.id }
    }
}
