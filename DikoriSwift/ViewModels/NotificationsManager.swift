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

        guard let token = resolvedAuthToken else {
            if notifications.isEmpty {
                notifications = AppNotification.samples()
            }
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await service.fetchMyNotifications(token: token)
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
        guard let token = resolvedAuthToken else { return }

        isLoading = true
        errorMessage = nil

        do {
            notifications = try await service.fetchMyNotifications(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func markAsRead(_ notification: AppNotification) async {
        guard !notification.isRead else { return }

        if let token = resolvedAuthToken {
            do {
                let updated = try await service.markNotificationAsRead(id: notification.id, token: token)
                if let index = notifications.firstIndex(where: { $0.id == updated.id }) {
                    notifications[index] = updated
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        } else if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            var updated = notification
            updated.isRead = true
            notifications[index] = updated
        }
    }

    func remove(_ notification: AppNotification) {
        notifications.removeAll { $0.id == notification.id }
    }

    private var resolvedAuthToken: String? {
        if let authToken, !authToken.isEmpty {
            return authToken
        }

        if let providerToken = service.tokenProvider?.authToken?.trimmingCharacters(in: .whitespacesAndNewlines),
           !providerToken.isEmpty {
            return providerToken
        }

        return nil
    }
}

#if DEBUG
extension NotificationsManager {
    static func preview(notifications: [AppNotification] = AppNotification.samples()) -> NotificationsManager {
        let manager = NotificationsManager(service: NotificationService())
        manager.notifications = notifications
        manager.isLoading = false
        manager.errorMessage = nil
        return manager
    }
}
#endif
