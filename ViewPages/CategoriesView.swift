//
//  CategoriesView.swift
//  DikoriLearn
//
//  Created by OpenAI Assistant on 2025-10-24.
//

import SwiftUI

struct CategoriesView: View {
    @State private var categories: [CategorySection] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    private let pageSize: Int = 100

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("التصنيفات")
                .navigationBarTitleDisplayMode(.inline)
        }
        .background(Color(.systemGroupedBackground))
        .task {
            await loadCategories()
        }
        .refreshable {
            await loadCategories(force: true)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && categories.isEmpty {
            loadingState
        } else if let errorMessage, categories.isEmpty {
            errorState(message: errorMessage)
        } else if categories.isEmpty {
            emptyState
        } else {
            List {
                ForEach(categories) { category in
                    NavigationLink {
                        SubcategoryListView(category: category)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.displayName)
                                    .font(.headline)
                                Text("\(category.productCount) منتج")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !category.subcategories.isEmpty {
                                Text("\(category.subcategories.count) فئات فرعية")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .background(Color(.systemGroupedBackground))
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("جارٍ تحميل التصنيفات...")
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
            Text("تعذر تحميل التصنيفات")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(action: {
                Task { await loadCategories(force: true) }
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.secondary)
            Text("لا توجد تصنيفات")
                .font(.headline)
            Text("سيتم عرض التصنيفات هنا بمجرد توفر منتجات.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    @MainActor
    private func loadCategories(force: Bool = false) async {
        if isLoading { return }

        isLoading = true
        errorMessage = nil
        if force {
            categories = []
        }

        defer { isLoading = false }

        do {
            var allProducts: [Product] = []
            var currentPage: Int = 1

            while true {
                let query = ProductQuery(page: currentPage, limit: pageSize)
                let fetched = try await ProductService.shared.fetchProducts(query: query)
                allProducts.append(contentsOf: fetched)

                if fetched.count < pageSize || fetched.isEmpty {
                    break
                }

                currentPage += 1

                if Task.isCancelled { return }
            }

            categories = Self.buildSections(from: allProducts)
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }

    private static func buildSections(from products: [Product]) -> [CategorySection] {
        var map: [String: CategoryAccumulator] = [:]

        for product in products {
            let main = product.mainCategory.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !main.isEmpty else { continue }

            var accumulator = map[main] ?? CategoryAccumulator()
            accumulator.productCount += 1

            let sub = product.subCategory.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sub.isEmpty {
                accumulator.subcategoryCounts[sub, default: 0] += 1
            }

            map[main] = accumulator
        }

        let sections = map.map { key, value in
            let subs = value.subcategoryCounts.map { subKey, count in
                SubcategoryItem(id: subKey, displayName: subKey, productCount: count)
            }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

            return CategorySection(
                id: key,
                displayName: key,
                productCount: value.productCount,
                subcategories: subs
            )
        }
        .sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }

        return sections
    }
}

private struct CategoryAccumulator {
    var productCount: Int = 0
    var subcategoryCounts: [String: Int] = [:]
}

struct CategorySection: Identifiable, Hashable {
    let id: String
    let displayName: String
    let productCount: Int
    let subcategories: [SubcategoryItem]
}

struct SubcategoryItem: Identifiable, Hashable {
    let id: String
    let displayName: String
    let productCount: Int
}

struct SubcategoryListView: View {
    let category: CategorySection

    var body: some View {
        List {
            if category.productCount > 0 {
                Section {
                    NavigationLink {
                        CategoryProductsView(
                            mainCategory: category.id,
                            subCategory: nil,
                            title: category.displayName
                        )
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("كل منتجات \(category.displayName)")
                                    .font(.headline)
                                Text("\(category.productCount) منتج")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.left")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }

            Section("الفئات الفرعية") {
                if category.subcategories.isEmpty {
                    Text("لا توجد فئات فرعية متاحة")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(category.subcategories) { subcategory in
                        NavigationLink {
                            CategoryProductsView(
                                mainCategory: category.id,
                                subCategory: subcategory.id,
                                title: subcategory.displayName
                            )
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(subcategory.displayName)
                                        .font(.body)
                                    Text("\(subcategory.productCount) منتج")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.left")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CategoryProductsView: View {
    @EnvironmentObject private var favoritesManager: FavoritesManager

    let mainCategory: String
    let subCategory: String?
    let title: String

    @State private var products: [Product] = []
    @State private var isLoading: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var errorMessage: String?
    @State private var nextPage: Int = 1
    @State private var hasMore: Bool = true

    private let pageSize: Int = 100

    private let columns = [
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18)
    ]

    var body: some View {
        Group {
            if isLoading && products.isEmpty {
                loadingState
            } else if let errorMessage, products.isEmpty {
                errorState(message: errorMessage)
            } else if products.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .center, spacing: 20) {
                        ForEach(products) { product in
                            NavigationLink {
                                ProductDetails(product: product)
                            } label: {
                                ProductCard(
                                    imageURL: product.primaryImageURL,
                                    title: product.displayName,
                                    subtitle: product.secondaryText,
                                    isFavorite: favoritesManager.isFavorite(product)
                                ) {
                                    toggleFavorite(for: product)
                                }
                            }
                            .buttonStyle(.plain)
                            .task {
                                await loadMoreIfNeeded(current: product)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)

                    if isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .task {
            await loadProducts()
        }
        .refreshable {
            await loadProducts(force: true)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.secondary)
            Text("لا توجد منتجات في هذا التصنيف")
                .font(.headline)
            Text("جرّب تصنيفًا مختلفًا أو عد لاحقًا.")
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

    private func toggleFavorite(for product: Product) {
        favoritesManager.toggleFavorite(product)
    }

    @MainActor
    private func loadProducts(force: Bool = false) async {
        if force {
            nextPage = 1
            hasMore = true
            products = []
        }

        guard hasMore || nextPage == 1 else { return }
        if isLoading || isLoadingMore { return }

        let pageToLoad = nextPage
        let shouldShowInitial = pageToLoad == 1 && products.isEmpty

        if shouldShowInitial {
            isLoading = true
        } else {
            isLoadingMore = true
        }

        errorMessage = nil

        defer {
            if shouldShowInitial {
                isLoading = false
            } else {
                isLoadingMore = false
            }
        }

        do {
            let query = ProductQuery(
                page: pageToLoad,
                limit: pageSize,
                mainCategory: mainCategory,
                subCategory: subCategory
            )
            let fetched = try await ProductService.shared.fetchProducts(query: query)

            if pageToLoad == 1 {
                products = fetched
            } else {
                let existingIDs = Set(products.map(\.id))
                let newItems = fetched.filter { !existingIDs.contains($0.id) }
                products.append(contentsOf: newItems)
            }

            favoritesManager.sync(with: products)

            if fetched.count < pageSize {
                hasMore = false
            } else {
                nextPage = pageToLoad + 1
            }
        } catch {
            if pageToLoad == 1 {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func loadMoreIfNeeded(current product: Product) async {
        guard hasMore else { return }
        guard !isLoading && !isLoadingMore else { return }
        guard let index = products.firstIndex(of: product) else { return }

        let thresholdIndex = products.index(
            products.endIndex,
            offsetBy: -6,
            limitedBy: products.startIndex
        ) ?? products.startIndex

        if index >= thresholdIndex {
            await loadProducts()
        }
    }
}

#Preview("Categories") {
    CategoriesView()
        .environmentObject(SessionManager.preview())
        .environmentObject(FavoritesManager())
        .environmentObject(NotificationsManager.preview())
        .environmentObject(OrdersManager.preview())
        .environmentObject(AppearanceManager.preview)
}

#Preview("Subcategory List") {
    NavigationStack {
        SubcategoryListView(
            category: CategorySection(
                id: "Furniture",
                displayName: "Furniture",
                productCount: 12,
                subcategories: [
                    SubcategoryItem(id: "Chairs", displayName: "Chairs", productCount: 5),
                    SubcategoryItem(id: "Tables", displayName: "Tables", productCount: 7)
                ]
            )
        )
    }
    .environmentObject(FavoritesManager())
}

#Preview("Category Products") {
    NavigationStack {
        CategoryProductsView(mainCategory: "Furniture", subCategory: "Chairs", title: "Chairs")
    }
    .environmentObject(FavoritesManager())
}
