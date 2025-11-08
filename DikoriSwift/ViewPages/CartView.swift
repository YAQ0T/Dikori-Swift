import SwiftUI

struct CartView: View {
    @EnvironmentObject private var cartManager: CartManager
    @StateObject private var checkoutViewModel = CheckoutViewModel()

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
            .alert(item: $checkoutViewModel.activeAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("حسنًا"))
                )
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

            checkoutSection
        }
        .listStyle(.insetGrouped)
        .background(Color(.systemGroupedBackground))
    }

    private var checkoutSection: some View {
        Section(header: Text("إتمام الطلب")) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("عنوان التوصيل", text: $checkoutViewModel.shippingAddress, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .disabled(checkoutViewModel.isLoading)
                    .onChange(of: checkoutViewModel.shippingAddress) { _ in
                        checkoutViewModel.inlineError = nil
                    }

                TextField("ملاحظات إضافية", text: $checkoutViewModel.notes, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .disabled(checkoutViewModel.isLoading)
                    .onChange(of: checkoutViewModel.notes) { _ in
                        checkoutViewModel.inlineError = nil
                    }
            }

            Picker("طريقة الدفع", selection: $checkoutViewModel.selectedPaymentMethod) {
                ForEach(checkoutViewModel.paymentOptions, id: \.self) { method in
                    Text(method.localizedTitle)
                        .tag(method)
                }
            }
            .pickerStyle(.segmented)
            .disabled(checkoutViewModel.isLoading)
            .onChange(of: checkoutViewModel.selectedPaymentMethod) { _ in
                checkoutViewModel.inlineError = nil
            }

            if let error = checkoutViewModel.inlineError, !error.isEmpty {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.vertical, 4)
            }

            Button {
                Task { await checkoutViewModel.submit(using: cartManager) }
            } label: {
                if checkoutViewModel.isLoading {
                    HStack {
                        ProgressView()
                        Text("جارٍ المعالجة...")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Text("إرسال الطلب")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(!checkoutViewModel.canSubmit(cartManager: cartManager))
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
    }
}
