import SwiftUI
import RecaptchaEnterprise

struct CartView: View {
    @EnvironmentObject private var cartManager: CartManager
    @EnvironmentObject private var ordersManager: OrdersManager

    @State private var shippingAddress: String = ""
    @State private var orderNotes: String = ""
    @State private var isPlacingOrder: Bool = false
    @State private var submissionError: String?
    @State private var createdOrder: Order?
    @State private var showSuccessAlert: Bool = false

    @State private var recaptchaClient: RecaptchaClient?
    @State private var isRecaptchaInitializing: Bool = false
    @State private var recaptchaError: String?

    @FocusState private var isAddressFieldFocused: Bool

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
            .task {
                await initializeRecaptchaClientIfNeeded()
            }
            .alert("تم إرسال الطلب", isPresented: $showSuccessAlert, presenting: createdOrder) { order in
                Button("حسنًا") { showSuccessAlert = false }
            } message: { order in
                VStack(alignment: .leading, spacing: 6) {
                    Text("تم استلام طلبك بنجاح.")
                    Text("رقم الطلب: \(order.id)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
            itemsSection
            summarySection
            deliverySection
            recaptchaSection
            actionSection
        }
        .listStyle(.insetGrouped)
        .background(Color(.systemGroupedBackground))
        .onChange(of: shippingAddress) { _ in
            if submissionError != nil { submissionError = nil }
        }
    }

    @ViewBuilder
    private var itemsSection: some View {
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
        Section(header: Text("بيانات التوصيل")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("عنوان التوصيل")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("أدخل عنوان التوصيل الكامل", text: $shippingAddress)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .focused($isAddressFieldFocused)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("ملاحظات (اختياري)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $orderNotes)
                    .frame(minHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.15))
                    )
            }
        }
    }

    private var recaptchaSection: some View {
        Section(header: Text("حماية الطلب")) {
            if isRecaptchaInitializing {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("جاري تهيئة reCAPTCHA...")
                        .foregroundStyle(.secondary)
                }
            } else if let recaptchaError {
                VStack(alignment: .leading, spacing: 10) {
                    Label("تعذّر تفعيل reCAPTCHA", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)

                    Text(recaptchaError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("إعادة المحاولة") {
                        Task { await initializeRecaptchaClientIfNeeded(force: true) }
                    }
                    .buttonStyle(.bordered)
                }
            } else if recaptchaClient != nil {
                Label("تم تفعيل حماية reCAPTCHA", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("لم يتم إعداد reCAPTCHA", systemImage: "exclamationmark.shield")
                        .foregroundStyle(.orange)
                    Text("يرجى التأكد من ضبط قيمة RECAPTCHA_SITE_KEY في إعدادات التطبيق.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var actionSection: some View {
        Section {
            if let submissionError {
                Text(submissionError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button(action: placeOrder) {
                if isPlacingOrder {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                        Spacer()
                    }
                } else {
                    Text("إتمام الطلب")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(checkoutButtonDisabled)
            .accessibilityLabel(Text("إتمام الطلب والتحقق من reCAPTCHA"))
        }
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

    private var trimmedAddress: String {
        shippingAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNotes: String? {
        let trimmed = orderNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var checkoutButtonDisabled: Bool {
        cartManager.isEmpty || trimmedAddress.isEmpty || isPlacingOrder || recaptchaClient == nil || isRecaptchaInitializing
    }

    @MainActor
    private func initializeRecaptchaClientIfNeeded(force: Bool = false) async {
        if isRecaptchaInitializing { return }
        if !force, recaptchaClient != nil { return }

        guard let siteKey = CheckoutConfiguration.recaptchaSiteKey, !siteKey.isEmpty else {
            recaptchaClient = nil
            recaptchaError = "لم يتم إعداد مفتاح reCAPTCHA. قم بتحديث إعدادات التطبيق." 
            return
        }

        isRecaptchaInitializing = true
        recaptchaError = nil

        if force {
            recaptchaClient = nil
        }

        do {
            recaptchaClient = try await Recaptcha.fetchClient(withSiteKey: siteKey)
        } catch let error as RecaptchaError {
            recaptchaClient = nil
            recaptchaError = error.errorMessage ?? error.localizedDescription
        } catch {
            recaptchaClient = nil
            recaptchaError = error.localizedDescription
        }

        isRecaptchaInitializing = false
    }

    @MainActor
    private func placeOrder() {
        guard !cartManager.isEmpty else { return }

        let address = trimmedAddress
        guard !address.isEmpty else {
            submissionError = "الرجاء إدخال عنوان التوصيل."
            isAddressFieldFocused = true
            return
        }

        guard let client = recaptchaClient else {
            submissionError = recaptchaError ?? "تعذّر تهيئة خدمة reCAPTCHA. حاول مجددًا."
            Task { await initializeRecaptchaClientIfNeeded(force: true) }
            return
        }

        let items = cartManager.items

        submissionError = nil
        isPlacingOrder = true

        Task {
            do {
                let token = try await client.execute(withAction: RecaptchaAction.login)
                let order = try await OrderService.shared.createCODOrder(
                    address: address,
                    notes: trimmedNotes,
                    items: items,
                    recaptchaToken: token,
                    recaptchaAction: CheckoutConfiguration.recaptchaActionName,
                    recaptchaMinScore: CheckoutConfiguration.recaptchaMinScore
                )

                await MainActor.run {
                    createdOrder = order
                    showSuccessAlert = true
                    isPlacingOrder = false
                    submissionError = nil
                    cartManager.clear()
                    shippingAddress = ""
                    orderNotes = ""
                    isAddressFieldFocused = false
                }

                await ordersManager.loadOrders(force: true)
            } catch let error as RecaptchaError {
                await MainActor.run {
                    isPlacingOrder = false
                    submissionError = error.errorMessage ?? error.localizedDescription
                }
            } catch {
                await MainActor.run {
                    isPlacingOrder = false
                    submissionError = error.localizedDescription
                }
            }
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
    }
}

private enum CheckoutConfiguration {
    static var recaptchaSiteKey: String? {
        if let envValue = ProcessInfo.processInfo.environment["RECAPTCHA_SITE_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !envValue.isEmpty {
            return envValue
        }

        if let bundleValue = Bundle.main.object(forInfoDictionaryKey: "RECAPTCHA_SITE_KEY") as? String {
            let trimmed = bundleValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return nil
    }

    static var recaptchaMinScore: Double? {
        if let envValue = ProcessInfo.processInfo.environment["RECAPTCHA_MIN_SCORE"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           let value = Double(envValue) {
            return value
        }

        if let object = Bundle.main.object(forInfoDictionaryKey: "RECAPTCHA_MIN_SCORE") {
            if let number = object as? NSNumber {
                return number.doubleValue
            }

            if let stringValue = object as? String {
                let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if let value = Double(trimmed) {
                    return value
                }
            }
        }

        return nil
    }

    static let recaptchaActionName: String = "login"
}
