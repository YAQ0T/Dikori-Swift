//
//  Products.swift
//  DikoriLearn
//
//  Created by Ahmad Salous on 19/10/2025.
//

import SwiftUI

public struct Products: View {
    @State private var searchText: String = ""
    @FocusState private var isSearching: Bool
    @State private var showOnlyFavorites: Bool = false

    @State private var products: [Product] = []
    @State private var favoriteIDs: Set<String> = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // أعمدة الشبكة (عمودان)
    private let columns = [
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18),
    ]

    // تصفية حسب البحث + المفضلة
    private var filteredProducts: [Product] {
        var base = products

        if !trimmedSearchText.isEmpty {
            let q = trimmedSearchText.lowercased()
            base = base.filter { product in
                product.displayName.lowercased().contains(q) ||
                product.secondaryText.lowercased().contains(q)
            }
        }

        if showOnlyFavorites {
            base = base.filter { favoriteIDs.contains($0.id) }
        }

        return base
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                if isLoading {
                    loadingState
                } else if let errorMessage {
                    errorState(message: errorMessage)
                } else if filteredProducts.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, alignment: .center, spacing: 20) {
                            ForEach(filteredProducts) { product in
                                // تنقّل إلى صفحة التفاصيل
                                NavigationLink {
                                    // مرّر المنتج الحقيقي لصفحة التفاصيل عند الربط بالـ API
                                    ProductDetails()
                                } label: {
                                    // استخدم ProductCard كما بنيناه بدون سعر/سلة
                                    ProductCard(
                                        imageURL: product.primaryImageURL,
                                        title: product.displayName,
                                        subtitle: product.secondaryText,
                                        isFavorite: favoriteIDs.contains(product.id)
                                    ) {
                                        toggleFavorite(for: product)
                                    }
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
            .task {
                await loadProducts()
            }
            .refreshable {
                await loadProducts(force: true)
            }
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

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("جارٍ تحميل المنتجات...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.orange)
            Text("تعذر تحميل المنتجات")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(action: {
                Task { await loadProducts(force: true) }
            }) {
                Text("أعد المحاولة")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(Color.accentColor.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Helpers

    private func toggleFavorite(for product: Product) {
        if favoriteIDs.contains(product.id) {
            favoriteIDs.remove(product.id)
        } else {
            favoriteIDs.insert(product.id)
        }
    }

    @MainActor
    private func loadProducts(force: Bool = false) async {
        if isLoading && !force { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await ProductService.shared.fetchProducts()
            products = fetched
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    Products()
}
