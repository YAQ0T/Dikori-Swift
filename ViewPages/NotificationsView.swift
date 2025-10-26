import SwiftUI

struct NotificationsView: View {
    var body: some View {
        NavigationStack {
            NotificationsContent()
                .navigationTitle("الإشعارات")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct NotificationsContent: View {
    @EnvironmentObject private var notificationsManager: NotificationsManager

    var body: some View {
        Group {
            if notificationsManager.isLoading && notificationsManager.notifications.isEmpty {
                loadingState
            } else if notificationsManager.notifications.isEmpty {
                emptyState
            } else {
                notificationsList
            }
        }
        .task {
            await notificationsManager.loadNotifications()
        }
        .refreshable {
            await notificationsManager.refresh()
        }
        .toolbar {
            if let errorMessage = notificationsManager.errorMessage, !errorMessage.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.orange)
                        .accessibilityLabel(Text(errorMessage))
                }
            }
        }
    }

    private var notificationsList: some View {
        List {
            ForEach(notificationsManager.notifications) { notification in
                NotificationCard(notification: notification)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            Task { await notificationsManager.markAsRead(notification) }
                        } label: {
                            Label("وضع كمقروء", systemImage: "envelope.open")
                        }
                        .tint(.blue)

                        Button(role: .destructive) {
                            notificationsManager.remove(notification)
                        } label: {
                            Label("حذف", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("جارٍ تحميل أحدث الإشعارات...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell.slash")
                .font(.system(size: 46, weight: .medium))
                .foregroundStyle(Color.gray.opacity(0.7))
            Text("لا توجد إشعارات بعد")
                .font(.headline)
            Text("سنخبرك فور وجود عروض أو تحديثات مهمة.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    NotificationsView()
        .environmentObject(NotificationsManager())
}
