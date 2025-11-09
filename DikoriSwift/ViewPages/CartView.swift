import SwiftUI

struct CartView: View {
    @EnvironmentObject private var cartManager: CartManager
    @EnvironmentObject private var ordersManager: OrdersManager

    @State private var isPresentingCheckout = false
    @State private var checkoutAddress: String = ""
    @State private var checkoutNotes: String = ""
    @State private var isSubmittingOrder = false
    @State private var checkoutErrorMessage: String?
    @State private var submittedOrder: Order?
    @State private var isShowingSuccessAlert = false

    @FocusState private var focusedCheckoutField: CheckoutField?

    private enum CheckoutField: Hashable {
        case address
        case notes
    }

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
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("سيتم دفع المبلغ عند التوصيل")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        checkoutErrorMessage = nil
                        focusedCheckoutField = .address
                        isPresentingCheckout = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("إتمام الطلب والدفع عند الاستلام")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                }
                .padding(.vertical, 8)
            } footer: {
                Text("لن يطلب منك إدخال بيانات البطاقة في التطبيق. سيتم تأكيد الطلب بعد الإرسال.")
                    .font(.footnote)
            }
        }
        .listStyle(.insetGrouped)
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $isPresentingCheckout, onDismiss: resetCheckoutForm) {
            checkoutSheet
        }
        .alert("تم إرسال الطلب", isPresented: $isShowingSuccessAlert, presenting: submittedOrder) { _ in
            Button("حسناً", role: .cancel) {
                submittedOrder = nil
            }
        } message: { order in
            Text("تم استلام طلبك وسيتم التواصل معك للتأكيد. رقم الطلب: \(order.id)")
        }
    }

    private var checkoutSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("عنوان التوصيل")) {
                    TextField("أدخل العنوان الكامل", text: $checkoutAddress, axis: .vertical)
                        .focused($focusedCheckoutField, equals: .address)
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(false)
                        .lineLimit(3, reservesSpace: true)
                }

                Section(header: Text("ملاحظات (اختياري)")) {
                    TextField("أي تفاصيل إضافية للمندوب", text: $checkoutNotes, axis: .vertical)
                        .focused($focusedCheckoutField, equals: .notes)
                        .lineLimit(3, reservesSpace: true)
                }

                Section(header: Text("ملخص الطلب")) {
                    HStack {
                        Text("عدد العناصر")
                        Spacer()
                        Text("\(cartManager.totalItems)")
                    }

                    HStack {
                        Text("الإجمالي")
                        Spacer()
                        Text(cartManager.formattedTotalPrice)
                            .font(.headline)
                    }
                }

                if let checkoutErrorMessage {
                    Section {
                        Text(checkoutErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("تأكيد الطلب")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { isPresentingCheckout = false }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSubmittingOrder {
                        ProgressView()
                    } else {
                        Button("إرسال") { submitCashOnDeliveryOrder() }
                            .disabled(checkoutAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || cartManager.isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isSubmittingOrder)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if isPresentingCheckout { focusedCheckoutField = .address }
            }
        }
    }

    private func submitCashOnDeliveryOrder() {
        let trimmedAddress = checkoutAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            checkoutErrorMessage = "يرجى إدخال عنوان التوصيل"
            focusedCheckoutField = .address
            return
        }

        checkoutErrorMessage = nil
        isSubmittingOrder = true

        let notes = checkoutNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedNotes = notes.isEmpty ? nil : notes

        Task {
            do {
                let order = try await OrderService.shared.createCashOnDeliveryOrder(
                    address: trimmedAddress,
                    notes: resolvedNotes,
                    items: cartManager.items
                )

                await MainActor.run {
                    submittedOrder = order
                    cartManager.clear()
                    isSubmittingOrder = false
                    isPresentingCheckout = false
                    isShowingSuccessAlert = true
                }

                await ordersManager.refresh()
            } catch {
                await MainActor.run {
                    checkoutErrorMessage = error.localizedDescription
                    isSubmittingOrder = false
                }
            }
        }
    }

    private func resetCheckoutForm() {
        checkoutAddress = ""
        checkoutNotes = ""
        checkoutErrorMessage = nil
        isSubmittingOrder = false
        focusedCheckoutField = nil
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
                .onChange(of: isQuantityFieldFocused) { _, newValue in
                    if !newValue {
                        commitQuantityChange()
                    }
                }
                .onChange(of: quantityText) { _, newValue in
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
        .onChange(of: item.quantity) { _, _ in
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
    }
}
