import SwiftUI

struct CheckoutView: View {
    @EnvironmentObject private var cartManager: CartManager
    @EnvironmentObject private var ordersManager: OrdersManager
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss

    let onCompleted: (Order) -> Void

    @State private var shippingAddress: String = ""
    @State private var notes: String = ""
    @State private var acceptedPolicies: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var isShowingError: Bool = false

    @StateObject private var recaptchaClient = RecaptchaV3Client()

    private var isAuthenticated: Bool { sessionManager.session != nil }
    private var requestItems: [OrderService.CreateCashOnDeliveryOrderRequest.Item] {
        cartManager.items.map { item in
            OrderService.CreateCashOnDeliveryOrderRequest.Item(
                productId: item.productID,
                variantId: item.variantID,
                sku: nil,
                quantity: item.quantity,
                name: LocalizedText(ar: item.title, he: item.subtitle),
                color: item.colorName,
                measure: item.measure
            )
        }
    }

    private var trimmedNotes: String? {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        Form {
            if !isAuthenticated {
                Section {
                    Label("يلزم تسجيل الدخول لإتمام الطلب بالدفع عند الاستلام", systemImage: "lock.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }

            Section("بيانات التوصيل") {
                TextField("العنوان التفصيلي", text: $shippingAddress, axis: .vertical)
                    .lineLimit(2...4)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                TextField("ملاحظات إضافية (اختياري)", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("ملخص السلة") {
                ForEach(cartManager.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Spacer()
                            Text("x\(item.quantity)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let options = item.optionsSummary, !options.isEmpty {
                            Text(options)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(cartManager.formattedPrice(item.totalPrice))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                HStack {
                    Text("الإجمالي")
                        .font(.headline)
                    Spacer()
                    Text(cartManager.formattedTotalPrice)
                        .font(.headline)
                }
            }

            Section {
                Toggle(isOn: $acceptedPolicies) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("أوافق على سياسة الإرجاع والتبديل وسياسة الخصوصية")
                            .font(.subheadline)
                        Text("تأكيدك يعني اطلاعك على الشروط المرتبطة بالشراء.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button(action: submitOrder) {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("تأكيد الطلب بالدفع عند الاستلام")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(submitDisabled)
            }
        }
        .navigationTitle("إتمام الطلب")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("إلغاء") { dismiss() }
            }
        }
        .overlay(alignment: .bottom) {
            RecaptchaWebViewContainer(client: recaptchaClient)
                .frame(width: 1, height: 1)
                .opacity(0.01)
        }
        .alert(errorMessage ?? "حدث خطأ غير متوقع", isPresented: $isShowingError, actions: {
            Button("حسنًا", role: .cancel) { }
        }, message: {
            if let errorMessage {
                Text(errorMessage)
            }
        })
    }

    private var submitDisabled: Bool {
        let trimmedAddress = shippingAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return isSubmitting || cartManager.isEmpty || !acceptedPolicies || !isAuthenticated || trimmedAddress.isEmpty
    }

    private func submitOrder() {
        guard !cartManager.isEmpty else {
            presentError(message: "السلة فارغة")
            return
        }

        guard isAuthenticated else {
            presentError(message: "يجب تسجيل الدخول لإكمال الطلب")
            return
        }

        let trimmedAddress = shippingAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            presentError(message: OrdersManagerError.missingAddress.errorDescription ?? "الرجاء إدخال عنوان التوصيل")
            return
        }

        guard acceptedPolicies else {
            presentError(message: "يرجى الموافقة على السياسات قبل المتابعة")
            return
        }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let token = try await recaptchaClient.execute()
                let order = try await ordersManager.createCashOnDeliveryOrder(
                    address: trimmedAddress,
                    notes: trimmedNotes,
                    items: requestItems,
                    recaptchaToken: token
                )
                await MainActor.run {
                    onCompleted(order)
                    dismiss()
                }
            } catch {
                if let localized = (error as? LocalizedError)?.errorDescription {
                    presentError(message: localized)
                } else {
                    presentError(message: error.localizedDescription)
                }
            }

            isSubmitting = false
        }
    }

    private func presentError(message: String) {
        errorMessage = message
        isShowingError = true
    }
}

#Preview {
    NavigationStack {
        CheckoutView { _ in }
            .environmentObject(CartManager.preview())
            .environmentObject(OrdersManager.preview())
            .environmentObject(SessionManager.preview())
    }
}
