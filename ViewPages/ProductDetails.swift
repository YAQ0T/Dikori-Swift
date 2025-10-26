//
//  ProductDetails.swift
//  DikoriLearn
//
//  Created by Ahmad Salous on 20/10/2025.
//

import SwiftUI
import Combine

struct ProductDetails: View {
    private let productID: String
    private let includeVariants: Bool
    private let initialProduct: Product?

    @EnvironmentObject private var favoritesManager: FavoritesManager
    @State private var product: Product?
    @State private var variants: [ProductVariant] = []
    @State private var isFetchingDetails = false
    @State private var loadError: String?

    @State private var quantity: Int = 1
    @State private var isFav: Bool = false
    @State private var selectedColor: String?
    @State private var selectedMeasure: String?
    @State private var isAddingToCart = false

    private let fallbackImageURL = URL(string: "https://i.imgur.com/KKPpSNy.png")!

    init(product: Product, includeVariants: Bool = true) {
        self.productID = product.id
        self.includeVariants = includeVariants
        self.initialProduct = product
        _product = State(initialValue: product)
    }

    init(productID: String, includeVariants: Bool = true) {
        self.productID = productID
        self.includeVariants = includeVariants
        self.initialProduct = nil
        _product = State(initialValue: nil)
    }

    private var currentProduct: Product? { product ?? initialProduct }

    private var productTitle: String {
        let title = currentProduct?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "تفاصيل المنتج" : title
    }

    private var productDescription: String {
        let description = currentProduct?.description.preferred.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return description.isEmpty ? "لا تتوفر وصف للمنتج حالياً." : description
    }

    private var shortSpecs: [String] {
        guard let product = currentProduct else { return [] }
        var specs: [String] = []
        if !product.mainCategory.isEmpty { specs.append(product.mainCategory) }
        if !product.subCategory.isEmpty { specs.append(product.subCategory) }
        if let category = product.category, !category.isEmpty { specs.append(category) }
        return specs.isEmpty ? ["—"] : specs
    }

    private var availableColors: [String] {
        let colorSet = Set(variants.map { $0.colorName })
        return colorSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func measures(for color: String?) -> [String] {
        let filtered = variants.filter { variant in
            guard let color else { return true }
            return variant.colorName == color
        }
        let measures = filtered.map { $0.displayMeasure }
        let measureSet = Set(measures)
        return measureSet.sorted { lhs, rhs in
            lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    private var availableMeasuresForSelectedColor: [String] {
        measures(for: selectedColor)
    }

    private var selectedVariant: ProductVariant? {
        if let color = selectedColor, let measure = selectedMeasure {
            return variants.first { $0.colorName == color && $0.displayMeasure == measure }
        }
        if let color = selectedColor {
            return variants.first { $0.colorName == color }
        }
        return variants.first
    }

    private var currentPrice: Double? {
        selectedVariant?.price.effectiveAmount
    }

    private var currentImageURL: URL? {
        if let url = selectedVariant?.primaryImageURL { return url }
        if let url = currentProduct?.primaryImageURL { return url }
        return fallbackImageURL
    }

    private var isContentAvailable: Bool {
        currentProduct != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        if isContentAvailable {
                            heroImage
                            infoSection
                            specsChips
                            optionsSection
                                .padding(.horizontal)
                            quantityStepper
                                .padding(.horizontal)
                                .padding(.top, 4)
                            descriptionSection
                        } else if isFetchingDetails {
                            loadingState
                        } else {
                            errorState
                        }

                        if let loadError {
                            errorBanner(message: loadError)
                                .padding(.horizontal)
                        }

                        Spacer(minLength: 120)
                    }
                    .padding(.top, 8)
                }

                if isFetchingDetails && !isContentAvailable {
                    ProgressView()
                        .scaleEffect(1.2)
                }

                bottomBar
            }
            .navigationTitle(productTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { toggleFavorite() } label: {
                        Image(systemName: isFav ? "heart.fill" : "heart")
                            .font(.headline)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .tint(.primary)
            .background(Color(.systemGroupedBackground))
            .task(id: productID) {
                await loadProductDetails()
            }
            .onAppear {
                ensureDefaultSelections()
                updateFavoriteState()
            }
            .onChange(of: selectedColor) { _ in
                ensureMeasureSelection()
            }
            .onChange(of: variants) { newValue in
                ensureDefaultSelections(for: newValue)
            }
            .onChange(of: product) { _ in
                updateFavoriteState()
            }
            .onReceive(favoritesManager.$favorites) { _ in
                updateFavoriteState()
            }
        }
    }

    // MARK: - Sections

    private var heroImage: some View {
        AsyncImage(url: currentImageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 360)
                    .clipped()
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 28,
                            bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 28
                        )
                    )
                    .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
                    .overlay(alignment: .bottomLeading) {
                        LinearGradient(colors: [.clear, .black.opacity(0.2)],
                                       startPoint: .top, endPoint: .bottom)
                        .frame(height: 80)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0, bottomLeadingRadius: 12,
                                bottomTrailingRadius: 12, topTrailingRadius: 0
                            )
                        )
                    }
                    .overlay(alignment: .topLeading) {
                        if let currentPrice, currentPrice > 0 {
                            PriceTag(text: formattedPrice(currentPrice))
                                .padding(12)
                        }
                    }

            case .empty:
                heroPlaceholder

            case .failure:
                heroPlaceholder

            @unknown default:
                heroPlaceholder
            }
        }
        .padding(.horizontal)
    }

    private var heroPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.secondary.opacity(0.08))
                .frame(height: 360)
            ProgressView()
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 28,
                bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 28
            )
        )
        .padding(.horizontal)
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(productTitle)
                .font(.title2).fontWeight(.bold)
                .lineLimit(2)

            HStack(spacing: 10) {
                if let currentPrice {
                    Text(formattedPrice(currentPrice))
                        .font(.headline)
                }

                HStack(spacing: 2) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .imageScale(.small)
                    }
                }
                .foregroundStyle(.yellow)
                Text("4.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    private var specsChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(shortSpecs, id: \.self) { spec in
                    Text(spec)
                        .font(.footnote)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule().stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal)
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !availableColors.isEmpty {
                Text("اللون")
                    .font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(availableColors, id: \.self) { color in
                            ColorSwatch(
                                label: color,
                                isSelected: selectedColor == color
                            ) { selectedColor = color }
                        }
                    }.padding(.horizontal)
                }
            }

            let measures = availableMeasuresForSelectedColor
            if !measures.isEmpty {
                Text("المقاس")
                    .font(.headline)
                FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(measures, id: \.self) { measure in
                        SizeChip(text: measure, isSelected: selectedMeasure == measure) {
                            selectedMeasure = measure
                        }
                    }
                }
            }
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("الوصف")
                .font(.headline)
            Text(productDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private var quantityStepper: some View {
        HStack {
            Text("الكمية")
                .font(.headline)
            Spacer()
            HStack(spacing: 0) {
                StepperButton(systemName: "minus") {
                    quantity = max(1, quantity - 1)
                }
                Divider().frame(height: 24)
                Text("\(quantity)")
                    .frame(minWidth: 38)
                    .font(.headline)
                Divider().frame(height: 24)
                StepperButton(systemName: "plus") {
                    quantity += 1
                }
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.15))
            }
        }
    }

    private var bottomBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("الإجمالي")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let total = totalPrice {
                        Text(formattedPrice(total))
                            .font(.headline)
                    } else {
                        Text("—")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    addToCart()
                } label: {
                    HStack {
                        if isAddingToCart {
                            ProgressView()
                        } else {
                            Image(systemName: "cart.badge.plus")
                        }
                        Text(isAddingToCart ? "جاري الإضافة..." : "أضِف إلى السلة")
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 14)
                    .frame(maxWidth: 220)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAddingToCart || selectedVariant == nil)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .overlay(Divider(), alignment: .top)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var totalPrice: Double? {
        guard let unitPrice = currentPrice else { return nil }
        return unitPrice * Double(quantity)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("جارٍ تحميل تفاصيل المنتج...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
    }

    private var errorState: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.secondary)
            Text("تعذّر تحميل المنتج")
                .font(.headline)
            Text("حاول مرة أخرى لاحقاً.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
    }

    private func errorBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
    }

    // MARK: - Networking

    private func loadProductDetails() async {
        await MainActor.run {
            isFetchingDetails = true
            loadError = nil
        }

        do {
            let response = try await ProductService.shared.fetchProduct(id: productID, withVariants: includeVariants)
            await MainActor.run {
                product = response.product
                if includeVariants {
                    variants = response.variants
                }
                isFetchingDetails = false
                ensureDefaultSelections()
            }
        } catch {
            await MainActor.run {
                loadError = error.localizedDescription
                isFetchingDetails = false
            }
        }
    }

    // MARK: - Actions

    private func addToCart() {
        guard !isAddingToCart, let variant = selectedVariant else { return }

        isAddingToCart = true

        let payload: [String: Any] = [
            "productId": productID,
            "variantId": variant.id,
            "color": variant.colorName,
            "measure": variant.displayMeasure,
            "unitPrice": currentPrice ?? 0,
            "quantity": quantity,
            "total": (currentPrice ?? 0) * Double(quantity)
        ]

        debugPrint("Add to cart payload:", payload)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isAddingToCart = false
        }
    }

    // MARK: - Helpers

    private func formattedPrice(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "ILS"
        formatter.locale = Locale(identifier: "ar")
        return formatter.string(from: amount as NSNumber) ?? "\(amount) ILS"
    }

    private func ensureDefaultSelections(for variants: [ProductVariant]? = nil) {
        let variants = variants ?? self.variants
        guard !variants.isEmpty else { return }

        if let selectedColor, variants.contains(where: { $0.colorName == selectedColor }) {
            ensureMeasureSelection(within: variants)
            return
        }

        selectedColor = variants.first?.colorName
        ensureMeasureSelection(within: variants)
    }

    private func ensureMeasureSelection(within variants: [ProductVariant]? = nil) {
        let variants = variants ?? self.variants
        guard !variants.isEmpty else { return }

        let measures = availableMeasuresForSelectedColor
        if let selectedMeasure, measures.contains(selectedMeasure) {
            return
        }
        selectedMeasure = measures.first ?? variants.first?.displayMeasure
    }

    private func ensureMeasureSelection() {
        ensureMeasureSelection(within: variants)
    }

    private func updateFavoriteState() {
        guard let product = currentProduct else { return }
        isFav = favoritesManager.isFavorite(product)
    }

    private func toggleFavorite() {
        guard let product = currentProduct else { return }
        favoritesManager.toggleFavorite(product)
        isFav = favoritesManager.isFavorite(product)
    }
}

// MARK: - Small Components

private struct PriceTag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline).fontWeight(.semibold)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule().stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

private struct StepperButton: View {
    let systemName: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

private struct ColorSwatch: View {
    let label: String
    let isSelected: Bool
    var onTap: () -> Void

    private var swatchColor: Color {
        switch label.lowercased() {
        case "red": return .red
        case "white": return .white
        case "silver": return .gray
        case "black": return .black
        case "blue": return .blue
        default: return .secondary
        }
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(swatchColor.gradient)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                if label.lowercased() == "white" {
                    Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .frame(width: 34, height: 34)
                }
            }
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2.5)
                    .frame(width: 40, height: 40)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("لون \(label)"))
        .padding(.vertical, 4)
    }
}

private struct SizeChip: View {
    let text: String
    let isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(.subheadline).fontWeight(.medium)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    isSelected ? Color.accentColor.opacity(0.12) : Color.clear,
                    in: Capsule()
                )
                .overlay(
                    Capsule().stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 1.6 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    init(horizontalSpacing: CGFloat = 8, verticalSpacing: CGFloat = 8) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + horizontalSpacing
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            sub.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            rowHeight = max(rowHeight, size.height)
            x += size.width + horizontalSpacing
        }
    }
}

#Preview {
    ProductDetails(product: Product(id: "demo"))
        .environmentObject(FavoritesManager())
}
