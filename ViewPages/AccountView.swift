import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var ordersManager: OrdersManager
    @EnvironmentObject private var notificationsManager: NotificationsManager
    @EnvironmentObject private var cartManager: CartManager

    private static let orderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var user: AuthUserDTO? { sessionManager.session?.user }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    profileSection
                    cartSection
                    ordersSection
                    notificationsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("حسابي")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadDataIfNeeded()
            }
            .refreshable {
                await refreshAll()
            }
        }
    }

    @ViewBuilder
    private var profileSection: some View {
        cardContainer(title: "الملف الشخصي") {
            VStack(alignment: .leading, spacing: 16) {
                if let user {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(user.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                        if let phone = user.phone, !phone.isEmpty {
                            Label(phone, systemImage: "phone.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        if let email = user.email, !email.isEmpty {
                            Label(email, systemImage: "envelope.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        if let role = user.role, !role.isEmpty {
                            Label(role, systemImage: "person.badge.shield.checkmark.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("لم يتم تسجيل الدخول")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .padding(.vertical, 4)

                NavigationLink {
                    SettingsView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape.fill")
                            .imageScale(.large)
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("إدارة الإعدادات")
                                .font(.headline)
                            Text("تخصيص المظهر والوصول إلى الدعم.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.left")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var cartSection: some View {
        cardContainer(title: "سلة التسوق") {
            VStack(alignment: .leading, spacing: 16) {
                if cartManager.isEmpty {
                    Text("سلتك فارغة حالياً")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    let summaryItems = Array(cartManager.items.prefix(3))

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(summaryItems) { item in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.subheadline)
                                        .lineLimit(1)

                                    if let options = item.optionsSummary, !options.isEmpty {
                                        Text(options)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                Text("x\(item.quantity)")
                                    .font(.callout.weight(.medium))
                                    .foregroundColor(.secondary)
                            }

                            if item.id != summaryItems.last?.id {
                                Divider()
                            }
                        }

                        if cartManager.items.count > summaryItems.count {
                            Text("و \(cartManager.items.count - summaryItems.count) منتجات أخرى في السلة...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        HStack {
                            Text("الإجمالي")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(cartManager.formattedTotalPrice)
                                .font(.headline)
                        }
                    }
                }

                NavigationLink {
                    CartView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "cart")
                            .imageScale(.medium)
                            .foregroundColor(.accentColor)
                        Text("عرض السلة")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.left")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var ordersSection: some View {
        cardContainer(title: "طلباتي") {
            if ordersManager.isLoading && ordersManager.orders.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("جارٍ تحميل الطلبات...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if ordersManager.orders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("لا توجد طلبات بعد")
                        .font(.headline)
                    Text("ابدأ التسوق لإضافة أول طلب لك.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(ordersManager.orders) { order in
                        orderCard(for: order)
                        if order.id != ordersManager.orders.last?.id {
                            Divider()
                        }
                    }
                }
            }

            if let errorMessage = ordersManager.errorMessage, !errorMessage.isEmpty {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundColor(.orange)
                    .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private var notificationsSection: some View {
        cardContainer(title: "الإشعارات") {
            NotificationsContent(layout: .embedded, autoLoad: false, supportsRefresh: false)
        }
    }

    private func orderCard(for order: Order) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(order.payment.reference ?? "#\(order.id.suffix(6))")
                    .font(.headline)
                Spacer()
                Text(order.status.localizedTitle)
                    .font(.subheadline)
                    .foregroundColor(color(for: order.status))
            }

            if let createdAt = order.createdAt {
                Text(Self.orderDateFormatter.string(from: createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(order.items.prefix(3)) { item in
                    HStack {
                        Text("• \(item.displayName)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(String(format: "x%d", item.quantity))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if order.items.count > 3 {
                    Text("و \(order.items.count - 3) منتجات أخرى...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Label(order.payment.localizedSummary, systemImage: "creditcard.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(order.formattedTotal())
                    .font(.headline)
            }
        }
    }

    private func cardContainer<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
    }

    private func color(for status: Order.Status) -> Color {
        switch status {
        case .pending, .waitingConfirmation:
            return .orange
        case .onTheWay:
            return .blue
        case .delivered:
            return .green
        case .cancelled:
            return .red
        case .unknown:
            return .gray
        }
    }

    private func loadDataIfNeeded() async {
        async let ordersTask: Void = ordersManager.loadOrders()

        if notificationsManager.notifications.isEmpty {
            async let notificationsTask: Void = notificationsManager.loadNotifications()
            _ = await (ordersTask, notificationsTask)
        } else {
            _ = await ordersTask
        }
    }

    private func refreshAll() async {
        async let ordersTask: Void = ordersManager.refresh()
        async let notificationsTask: Void = notificationsManager.refresh()
        _ = await (ordersTask, notificationsTask)
    }
}

private extension Order.PaymentDetails {
    var localizedSummary: String {
        var components: [String] = [method.localizedTitle]
        if status != .unknown {
            components.append(status.localizedTitle)
        }
        if !cardType.isEmpty {
            components.append(cardType)
        }
        if !cardLast4.isEmpty {
            components.append("••••\(cardLast4)")
        }
        return components.joined(separator: " • ")
    }
}

#Preview {
    AccountView()
        .environmentObject(SessionManager.preview())
        .environmentObject(OrdersManager.preview())
        .environmentObject(NotificationsManager.preview())
        .environmentObject(CartManager.preview())
}
