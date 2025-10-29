import SwiftUI

struct NotificationCard: View {
    let notification: AppNotification

    private var timeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: notification.createdAt, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(notification.title)
                    .font(.headline)
                Spacer()
                Text(timeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(notification.message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
                Image(systemName: notification.isRead ? "envelope.open.fill" : "envelope.badge")
                    .font(.caption)
                Text(notification.isRead ? "مقروء" : "جديد")
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(notification.isRead ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
            )
            .foregroundStyle(notification.isRead ? Color.green : Color.blue)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 8)
        )
    }
}

#Preview {
    NotificationCard(notification: AppNotification.samples().first!)
        .padding()
        .background(Color(.systemGroupedBackground))
}
