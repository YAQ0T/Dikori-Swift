import SwiftUI

struct CartView: View {
    @EnvironmentObject private var cartManager: CartManager
    @EnvironmentObject private var ordersManager: OrdersManager
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var isPresentingCheckout: Bool = false
    @State private var pendingOrder: Order?
    @State private var createdOrder: Order?
    @State private var showConfirmation: Bool = false

    var body: some View {
        content
            .navigationTitle("سلة التسوق")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !cartManager.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("إفراغ السلة", role: .destructive) {
                            withAnimation { cartManager.clear() }
                        }
                        .accessibilityLabel(Text("إفراغ السلة بالكامل"))
                    }
                }
            }
            .sheet(isPresented: $isPresentingCheckout, onDismiss: handleCheckoutDismissed) {
                NavigationStack {
                    CheckoutView { order in
                        pendingOrder = order
                        withAnimation { cartManager.clear() }
                        isPresentingCheckout = false
                    }
                }
                .environmentObject(cartManager)
                .environmentObject(ordersManager)
                .environmentObject(sessionManager)
            }
            .background(
                NavigationLink(isActive: Binding(
                    get: { showConfirmation && createdOrder != nil },
                    set: { newValue in
                        if !newValue {
                            showConfirmation = false
                            createdOrder = nil
                        }
                    }
                )) {
                    if let order = createdOrder {
                        OrderConfirmationView(order: order)
                    } else {
                        EmptyView()
                    }
                } label: {
                    EmptyView()
                }
                .hidden()
            )
    }

    @ViewBuilder
    private var content: some View {
        if cartManager.isEmpty {
            emptyState
        } else {
            listContent
        }
    }

    private var listContent: some View {
        List {
            Section {
                ForEach(cartManager.items) { item in
                    CartItemRow(
                        item: item,
                        formattedPrice: cartManager.formattedPrice,
                        onIncrease: { cartManager.increaseQuantity(for: item.id) },
                        onDecrease: { cartManager.decreaseQuantity(for: item.id) },
                        onUpdateQuantity: { cartManager.updateQuantity(for: item.id, to: $0) }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation { cartManager.remove(itemID: item.id) }
                        } label: {
                            Label("حذف", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: cartManager.removeItems)
            }

            Section(header: Text("ملخص")) {
                HStack {
                    Text("عدد العناصر")
                    Spacer()
                    Text("\(cartManager.totalItems)")
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("الإجمالي")
                    Spacer()
                    Text(cartManager.formattedTotalPrice)
                        .font(.headline)
                }

                Button {
                    isPresentingCheckout = true
                } label: {
                    Text(ordersManagerButtonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canCheckout)

                if sessionManager.session == nil {
                    Text("يجب تسجيل الدخول لمتابعة الدفع عند الاستلام.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color(.systemGroupedBackground))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart")
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(.secondary)
            Text("سلتك فارغة")
                .font(.title3.weight(.semibold))
            Text("ابدأ بالتسوق لإضافة منتجات إلى سلة المشتريات.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

private extension CartView {
    var canCheckout: Bool {
        !cartManager.isEmpty && sessionManager.session != nil
    }

    var ordersManagerButtonTitle: String {
        sessionManager.session == nil ? "سجل الدخول لإتمام الطلب" : "إتمام الطلب"
    }

    func handleCheckoutDismissed() {
        if let order = pendingOrder {
            createdOrder = order
            pendingOrder = nil
            showConfirmation = true
        }
    }
}

private struct CartItemRow: View {
    let item: CartItem
    let formattedPrice: (Double) -> String
    let onIncrease: () -> Void
    let onDecrease: () -> Void
    let onUpdateQuantity: (Int) -> Void

    @State private var quantityText: String = ""
    @FocusState private var isQuantityFieldFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            AsyncImage(url: item.imageURL) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Rectangle().fill(Color.gray.opacity(0.15))
                        ProgressView()
                    }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)

                if let options = item.optionsSummary, !options.isEmpty {
                    Text(options)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if !item.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        quantityControl
                        Spacer()
                        Text(formattedPrice(item.unitPrice))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("الإجمالي")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formattedPrice(item.totalPrice))
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(item.title)، الكمية \(item.quantity). الإجمالي \(formattedPrice(item.totalPrice))."))
    }

    private var quantityControl: some View {
        HStack(spacing: 0) {
            Button(action: onDecrease) {
                Image(systemName: "minus")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)

            TextField("", text: $quantityText)
                .font(.body.monospacedDigit())
                .frame(minWidth: 36)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .focused($isQuantityFieldFocused)
                .submitLabel(.done)
                .onSubmit(commitQuantityChange)
                .onChange(of: isQuantityFieldFocused) { isFocused in
                    if !isFocused {
                        commitQuantityChange()
                    }
                }
                .onChange(of: quantityText) { newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered != newValue {
                        quantityText = filtered
                    }
                }

            Button(action: onIncrease) {
                Image(systemName: "plus")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(.thinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.secondary.opacity(0.2))
        )
        .onAppear(perform: syncQuantityText)
        .onChange(of: item.quantity) { _ in
            syncQuantityText()
        }
    }

    private func syncQuantityText() {
        quantityText = String(item.quantity)
    }

    private func commitQuantityChange() {
        guard let value = Int(quantityText), value > 0 else {
            syncQuantityText()
            return
        }
        if value != item.quantity {
            onUpdateQuantity(value)
        }
        syncQuantityText()
    }
}

#Preview {
    NavigationStack {
        CartView()
            .environmentObject(CartManager.preview())
            .environmentObject(OrdersManager.preview())
            .environmentObject(SessionManager.preview())
    }
}
