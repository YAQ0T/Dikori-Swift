import SwiftUI

struct CartView: View {
    @EnvironmentObject private var cartManager: CartManager
    @EnvironmentObject private var ordersManager: OrdersManager

    @State private var deliveryAddress: String = ""
    @State private var orderNotes: String = ""
    @State private var isPlacingOrder: Bool = false
    @State private var isAlertPresented: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String?

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
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
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("تم") {
                        focusedField = nil
                    }
                }
            }
            .alert(alertTitle, isPresented: $isAlertPresented) {
                Button("حسناً", role: .cancel) {}
            } message: {
                if let alertMessage {
                    Text(alertMessage)
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
            cartItemsSection
            summarySection
            deliverySection
            checkoutSection
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

    private var cartItemsSection: some View {
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
    }

    private var summarySection: some View {
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
    }

    private var deliverySection: some View {
        Section("تفاصيل التوصيل") {
            VStack(alignment: .leading, spacing: 8) {
                Text("العنوان الكامل")
                    .font(.subheadline.weight(.semibold))

                multilineField(
                    text: $deliveryAddress,
                    placeholder: "اكتب عنوان التوصيل بالتفصيل",
                    field: .address
                )
                .frame(minHeight: 96)
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

            VStack(alignment: .leading, spacing: 8) {
                Text("ملاحظات إضافية (اختياري)")
                    .font(.subheadline.weight(.semibold))

                multilineField(
                    text: $orderNotes,
                    placeholder: "أخبرنا بأي تفاصيل تساعد فريق التوصيل",
                    field: .notes
                )
                .frame(minHeight: 80)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
        }
    }

    private var checkoutSection: some View {
        Section("إتمام الطلب") {
            Text("سيتم الدفع نقدًا عند التوصيل. سيتواصل فريقنا معك لتأكيد تفاصيل الطلب والتسليم.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await placeOrder() }
            } label: {
                HStack {
                    if isPlacingOrder {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .imageScale(.large)
                    }
                    Text(isPlacingOrder ? "جاري إرسال الطلب" : "تأكيد الطلب")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isAddressValid || isPlacingOrder)
            .accessibilityLabel(Text("إتمام الطلب والدفع عند الاستلام"))
        }
    }

    private var isAddressValid: Bool {
        !deliveryAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func multilineField(text: Binding<String>, placeholder: String, field: Field) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
            }

            TextEditor(text: text)
                .focused($focusedField, equals: field)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(false)
                .padding(4)
                .background(Color.clear)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.2))
        )
    }

    @MainActor
    private func placeOrder() async {
        focusedField = nil

        guard !cartManager.isEmpty else {
            presentAlert(title: "السلة فارغة", message: "أضف منتجات قبل إتمام الطلب.")
            return
        }

        let trimmedAddress = deliveryAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            presentAlert(title: "العنوان مطلوب", message: "يرجى إدخال عنوان التوصيل قبل المتابعة.")
            return
        }

        let trimmedNotes = orderNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestItems = cartManager.items.map { $0.asOrderRequestItem() }

        let recaptchaResult: RecaptchaManager.TokenResult
        do {
            recaptchaResult = try await RecaptchaManager.shared.generateToken()
        } catch {
            presentAlert(title: "فشل التحقق", message: error.localizedDescription)
            return
        }
        let request = OrderService.CashOnDeliveryOrderRequest(
            address: trimmedAddress,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            items: requestItems,
            recaptchaToken: recaptchaResult.token,
            recaptchaAction: recaptchaResult.action,
            recaptchaMinScore: recaptchaResult.minScore
        )

        isPlacingOrder = true
        defer { isPlacingOrder = false }

        do {
            let order = try await OrderService.shared.createCashOnDeliveryOrder(request)

            await ordersManager.refresh()

            withAnimation {
                cartManager.clear()
            }

            deliveryAddress = ""
            orderNotes = ""

            let successMessage = "تم استلام طلبك بنجاح. رقم الطلب: \(order.id)."
            presentAlert(title: "تم إنشاء الطلب", message: successMessage)
        } catch {
            presentAlert(title: "تعذّر إتمام الطلب", message: error.localizedDescription)
        }
    }

    private func presentAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        isAlertPresented = true
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
    }
}
