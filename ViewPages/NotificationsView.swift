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
    enum Layout {
        case list
        case embedded
    }

    private let layout: Layout
    private let autoLoad: Bool
    private let supportsRefresh: Bool

    @EnvironmentObject private var notificationsManager: NotificationsManager

    init(layout: Layout = .list, autoLoad: Bool = true, supportsRefresh: Bool = true) {
        self.layout = layout
        self.autoLoad = autoLoad
        self.supportsRefresh = supportsRefresh
    }

    var body: some View {
        switch layout {
        case .list:
            listLayout
        case .embedded:
            embeddedLayout
        }
    }

    private var listLayout: some View {
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
            guard autoLoad else { return }
            await notificationsManager.loadNotifications()
        }
        .refreshable {
            guard supportsRefresh else { return }
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

    private var embeddedLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            if notificationsManager.isLoading && notificationsManager.notifications.isEmpty {
                loadingStateEmbedded
            } else if notificationsManager.notifications.isEmpty {
                emptyStateEmbedded
            } else {
                VStack(spacing: 12) {
                    ForEach(notificationsManager.notifications) { notification in
                        NotificationCard(notification: notification)
                            .onTapGesture {
                                Task { await notificationsManager.markAsRead(notification) }
                            }
                    }
                }
            }

            if let errorMessage = notificationsManager.errorMessage, !errorMessage.isEmpty {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
        }
        .task {
            guard autoLoad else { return }
            await notificationsManager.loadNotifications()
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

    private var loadingStateEmbedded: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("جارٍ تحميل أحدث الإشعارات...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyStateEmbedded: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("لا توجد إشعارات بعد")
                .font(.headline)
            Text("سنخبرك فور وجود عروض أو تحديثات مهمة.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NotificationsView()
        .environmentObject(NotificationsManager.preview())
}
