//
//  Products.swift
//  DikoriLearn
//
//  Created by Ahmad Salous on 19/10/2025.
//

import SwiftUI

// نموذج مبسّط لعنصر منتج في الشبكة (ملخّص)
private struct ProductMini: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let imageURL: URL?
    var isFavorite: Bool = false
}

public struct Products: View {
    @State private var searchText: String = ""
    @FocusState private var isSearching: Bool
    @State private var showOnlyFavorites: Bool = false

    // بيانات تجريبية — استبدلها ببياناتك لاحقًا
    @State private var items: [ProductMini] = [
        ProductMini(title: "PCD 1/2 X 30 X 120", subtitle: "نصلة سي إن سي ممتازة", imageURL: URL(string: "https://i.imgur.com/KKPpSNy.png")),
        ProductMini(title: "PCD 1/4 X 20 X 80",  subtitle: "دقة عالية وأداء ثابت", imageURL: URL(string: "https://i.imgur.com/KKPpSNy.png")),
        ProductMini(title: "PCD 3/8 X 25 X 100", subtitle: "مصمّم للعمر الطويل",   imageURL: URL(string: "https://i.imgur.com/KKPpSNy.png")),
        ProductMini(title: "PCD 1/2 X 40 X 120", subtitle: "مناسب للمواد الصلبة",  imageURL: URL(string: "https://i.imgur.com/KKPpSNy.png"), isFavorite: true),
        ProductMini(title: "PCD 8mm X 30 X 90",  subtitle: "توازن ممتاز",          imageURL: URL(string: "https://i.imgur.com/KKPpSNy.png")),
        ProductMini(title: "PCD 10mm X 35 X 110",subtitle: "اعتمادية عالية",       imageURL: URL(string: "https://i.imgur.com/KKPpSNy.png")),
        ProductMini(title: "PCD 12mm X 30 X 120",subtitle: "جودة احترافية",        imageURL: URL(string: "https://i.imgur.com/KKPpSNy.png"), isFavorite: true),
        ProductMini(title: "PCD 6mm X 20 X 60",  subtitle: "خيار اقتصادي",         imageURL: URL(string: "https://i.imgur.com/KKPpSNy.png")),
        ProductMini(title: "PCD 1/2 X 30 X 150", subtitle: "ثبات عند السرعات العالية", imageURL: URL(string: "https://i.imgur.com/KKPpSNy.png")),
        ProductMini(title: "PCD 14mm X 40 X 130",subtitle: "أداء صناعي",           imageURL: URL(string: "https://i.imgur.com/KKPpSNy.png"))
    ]

    // أعمدة الشبكة (عمودان)
    private let columns = [
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18),
    ]

    // تصفية حسب البحث + المفضلة
    private var filteredItems: [ProductMini] {
        let base = items.filter { item in
            guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
            let q = searchText.lowercased()
            return item.title.lowercased().contains(q) || item.subtitle.lowercased().contains(q)
        }
        return showOnlyFavorites ? base.filter { $0.isFavorite } : base
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                if filteredItems.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, alignment: .center, spacing: 20) {
                            ForEach(filteredItems) { product in
                                // تنقّل إلى صفحة التفاصيل
                                NavigationLink {
                                    // مرّر المنتج الحقيقي لصفحة التفاصيل عند الربط بالـ API
                                    ProductDetails()
                                } label: {
                                    // استخدم ProductCard كما بنيناه بدون سعر/سلة
                                    ProductCard(
                                        imageURL: product.imageURL,
                                        title: product.title,
                                        subtitle: product.subtitle,
                                        isFavorite: product.isFavorite
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Dikori || ديكوري ")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // إعدادات (مثال)
                Button(action: {}) {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                // شريط البحث بكبسولة
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").opacity(0.6)
                    TextField("ابحث عن منتج...", text: $searchText)
                        .focused($isSearching)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .submitLabel(.search)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())

                // قلب: إظهار المفضلة فقط
                Button {
                    showOnlyFavorites.toggle()
                } label: {
                    Image(systemName: showOnlyFavorites ? "heart.circle.fill" : "heart")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(showOnlyFavorites ? "عرض المفضلة مُفعّل" : "عرض المفضلة"))
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemBackground).opacity(0.98))

            // خط سفلي (border-bottom)
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.secondary)
            Text("لا توجد نتائج")
                .font(.headline)
            Text("جرّب كلمة بحث مختلفة أو ألغِ فلتر المفضلة.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    Products()
}
