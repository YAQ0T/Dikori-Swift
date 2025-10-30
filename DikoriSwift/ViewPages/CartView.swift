import SwiftUI

struct CartView: View {
    @EnvironmentObject private var cartManager: CartManager

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
                        onDecrease: { cartManager.decreaseQuantity(for: item.id) }
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

private struct CartItemRow: View {
    let item: CartItem
    let formattedPrice: (Double) -> String
    let onIncrease: () -> Void
    let onDecrease: () -> Void

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

            Text("\(item.quantity)")
                .font(.body.monospacedDigit())
                .frame(minWidth: 32)

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
    }
}

#Preview {
    NavigationStack {
        CartView()
            .environmentObject(CartManager.preview())
    }
}
