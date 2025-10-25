//
//  ProductDetails.swift
//  DikoriLearn
//
//  Created by Ahmad Salous on 20/10/2025.
//

import SwiftUI

// MARK: - Models

struct Variant: Identifiable, Hashable {
    let id = UUID()
    let color: String
    let size: String
    let price: Double
    let imageURL: URL
}

struct ProductDetails: View {
    // بيانات المنتج العامة
    let title: String = "PCD 1/2 X 30 X 120"
    let fallbackPrice: Double = 50.0
    let fallbackImageURL: URL = URL(string: "https://i.imgur.com/KKPpSNy.png")!
    let shortSpecs: [String] = ["PCD", "Ø30", "L120", "1/2\" Shaft"]

    // أمثلة Variants — لاحقًا اجلبها من API
    let variants: [Variant] = {
        let base = "https://i.imgur.com/KKPpSNy.png"
        func url(_ s: String) -> URL { URL(string: s)! }
        // يمكنك تبديل الروابط بصور مختلفة لكل لون إن رغبت
        return [
            Variant(color: "Red",    size: "23cm", price: 55, imageURL: url(base)),
            Variant(color: "Red",    size: "25cm", price: 58, imageURL: url(base)),
            Variant(color: "Red",    size: "27cm", price: 61, imageURL: url(base)),
            Variant(color: "Red",    size: "29cm", price: 65, imageURL: url(base)),
            Variant(color: "White",  size: "23cm", price: 54, imageURL: url(base)),
            Variant(color: "White",  size: "25cm", price: 57, imageURL: url(base)),
            Variant(color: "White",  size: "27cm", price: 60, imageURL: url(base)),
            Variant(color: "Silver", size: "23cm", price: 56, imageURL: url(base)),
            Variant(color: "Silver", size: "25cm", price: 59, imageURL: url(base)),
            Variant(color: "Silver", size: "27cm", price: 62, imageURL: url(base)),
            Variant(color: "Silver", size: "29cm", price: 66, imageURL: url(base)),
        ]
    }()

    // حالة الواجهة
    @State private var isLoading = false
    @State private var quantity: Int = 1
    @State private var isFav: Bool = false

    @State private var selectedColor: String?
    @State private var selectedSize: String?

    // MARK: - Derived

    private var availableColors: [String] {
        Array(Set(variants.map { $0.color })).sorted()
    }

    private var availableSizesForSelectedColor: [String] {
        if let c = selectedColor {
            return Array(Set(variants.filter { $0.color == c }.map { $0.size }))
                .sorted(by: sizeComparator)
        } else {
            return Array(Set(variants.map { $0.size })).sorted(by: sizeComparator)
        }
    }

    private var selectedVariant: Variant? {
        guard let c = selectedColor, let s = selectedSize else { return nil }
        return variants.first { $0.color == c && $0.size == s }
    }

    private var currentPrice: Double {
        selectedVariant?.price ?? fallbackPrice
    }

    private var totalPrice: Double {
        currentPrice * Double(quantity)
    }

    private var currentImageURL: URL {
        selectedVariant?.imageURL ?? fallbackImageURL
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        heroImage

                        infoSection

                        specsChips

                        // خيارات المنتج (ألوان + أحجام)
                        optionsSection
                            .padding(.horizontal)

                        quantityStepper
                            .padding(.horizontal)
                            .padding(.top, 4)

                        descriptionSection

                        // مساحة إضافية حتى لا يغطي الشريط السفلي أي محتوى
                        Spacer(minLength: 120)
                    }
                    .padding(.top, 8)
                }

                bottomBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
//                    Button(action: { /* handled by parent Navigation */ }) {
//                        Image(systemName: "chevron.backward")
//                            .font(.headline)
//                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isFav.toggle() } label: {
                        Image(systemName: isFav ? "heart.fill" : "heart")
                            .font(.headline)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .tint(.primary)
            .background(Color(.systemGroupedBackground))
            .onAppear {
                // تحديد اختيارات افتراضية أول مرة
                if selectedColor == nil { selectedColor = availableColors.first }
                if selectedSize == nil { selectedSize = availableSizesForSelectedColor.first }
            }
            .onChange(of: selectedColor) { _, _ in
                // عند تغيير اللون، عدّل المقاس ليتوافق مع المتاح لهذا اللون
                let sizes = availableSizesForSelectedColor
                if let selectedSize, !sizes.contains(selectedSize) {
                    self.selectedSize = sizes.first
                }
            }
        }
    }

    // MARK: - Views

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
                        PriceTag(text: formattedPrice(currentPrice))
                            .padding(12)
                    }

            case .empty:
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

            case .failure(_):
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.secondary.opacity(0.08))
                        .frame(height: 360)
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 28,
                        bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 28
                    )
                )
            @unknown default:
                EmptyView()
            }
        }
        .padding(.horizontal)
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2).fontWeight(.bold)
                .lineLimit(2)

            HStack(spacing: 10) {
                Text(formattedPrice(currentPrice))
                    .font(.headline)

                HStack(spacing: 2) {
                    ForEach(0..<5) { i in
                        Image(systemName: i < 5 ? "star.fill" : "star")
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
            // الألوان
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

            // الأحجام
            Text("المقاس")
                .font(.headline)
            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(availableSizesForSelectedColor, id: \.self) { size in
                    SizeChip(text: size, isSelected: selectedSize == size) {
                        selectedSize = size
                    }
                }
            }


        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("الوصف")
                .font(.headline)
            Text("نصلة سي إن سي ممتازة بجودة عالية ومتانة موثوقة، مناسبة للأعمال الدقيقة على المواد الصلبة. تصميم PCD محسّن لعمر أطول وأداء ثابت.")
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
                    Text(formattedPrice(totalPrice))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    addToCart()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "cart.badge.plus")
                        }
                        Text(isLoading ? "جاري الإضافة..." : "أضِف إلى السلة")
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 14)
                    .frame(maxWidth: 220)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || selectedVariant == nil) // يتطلّب اختيارًا صالحًا
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .overlay(Divider(), alignment: .top)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Actions

    private func addToCart() {
        guard !isLoading else { return }
        guard let variant = selectedVariant else { return }

        isLoading = true

        let payload: [String: Any] = [
            "title": title,
            "color": variant.color,
            "size": variant.size,
            "unitPrice": variant.price,
            "quantity": quantity,
            "total": variant.price * Double(quantity)
        ]

        // استخدام فعلي — استبدلها بمناداة ViewModel/Service لاحقًا
        debugPrint("Add to cart payload:", payload)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isLoading = false
        }
    }



    // MARK: - Helpers

    private func formattedPrice(_ n: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = "ILS"
        fmt.locale = Locale(identifier: "ar")
        return fmt.string(from: n as NSNumber) ?? "\(n) ILS"
    }

    private func sizeComparator(_ a: String, _ b: String) -> Bool {
        // يحاول ترتيب 23cm < 25cm < 27cm ...
        func numeric(_ s: String) -> Double {
            Double(s.replacingOccurrences(of: "cm", with: "")
                .replacingOccurrences(of: " ", with: "")) ?? 0
        }
        return numeric(a) < numeric(b)
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

    // تعيين لون تقريبي لاسم اللون
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
                    // حدود رمادية لتمييز الأبيض
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
        .accessibilityLabel(Text("لون \(localized(label))"))
        .padding(.vertical, 4)
    }

    private func localized(_ s: String) -> String { s } // بدّلها لاحقًا إذا أردت ترجمة الأسماء
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

// MARK: - Simple Flow Layout for size chips

/// Grid مرن بسيط لتصفيف العناصر (بديل خفيف لـ LazyVGrid بحجم تلقائي)
/// FlowLayout بسيط لتوزيع العناصر على أسطر متعددة
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


// MARK: - Preview

#Preview {
    ProductDetails()
}
