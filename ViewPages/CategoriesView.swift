import SwiftUI

struct CategoriesView: View {
    @StateObject private var viewModel = CategoriesViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("التصنيفات")
                .navigationBarTitleDisplayMode(.inline)
                .background(Color(.systemGroupedBackground))
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.categories.isEmpty {
            ScrollView {
                loadingState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            }
            .background(Color(.systemGroupedBackground))
            .refreshable {
                await viewModel.reload()
            }
        } else if let error = viewModel.errorMessage, viewModel.categories.isEmpty {
            ScrollView {
                errorState(message: error)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            }
            .background(Color(.systemGroupedBackground))
            .refreshable {
                await viewModel.reload()
            }
        } else if viewModel.categories.isEmpty {
            ScrollView {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            }
            .background(Color(.systemGroupedBackground))
            .refreshable {
                await viewModel.reload()
            }
        } else {
            categoriesList
        }
    }

    private var categoriesList: some View {
        List {
            ForEach(viewModel.categories) { category in
                NavigationLink {
                    SubcategoryListView(category: category)
                } label: {
                    CategoryRow(category: category)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.reload()
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("جارٍ تحميل التصنيفات...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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
            Button("أعد المحاولة") {
                Task {
                    await viewModel.reload()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("لا توجد تصنيفات متاحة")
                .font(.headline)
            Text("سيتم عرض التصنيفات هنا بمجرد توفّرها.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CategoryRow: View {
    let category: CategoriesViewModel.CategorySummary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)
                Text("\(category.subcategories.count) تصنيف فرعي")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.left")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
}

private struct SubcategoryListView: View {
    let category: CategoriesViewModel.CategorySummary

    var body: some View {
        Group {
            if category.subcategories.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("لا توجد تصنيفات فرعية")
                            .font(.headline)
                        Text("يمكنك استعراض المنتجات المرتبطة بهذا التصنيف لاحقًا.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            } else {
                List {
                    ForEach(category.subcategories) { subcategory in
                        NavigationLink {
                            CategoryProductsView(
                                mainCategory: category.name,
                                subCategory: subcategory.name
                            )
                        } label: {
                            HStack {
                                Text(subcategory.name)
                                    .font(.body)
                                Spacer()
                                Image(systemName: "chevron.left")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

private struct CategoryProductsView: View {
    let mainCategory: String
    let subCategory: String

    @EnvironmentObject private var favoritesManager: FavoritesManager

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
        ScrollView {
            if isLoading && products.isEmpty {
                loadingState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 48)
            } else if let errorMessage, products.isEmpty {
                errorState(message: errorMessage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 48)
            } else if products.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 48)
            } else {
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
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(subCategory)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProducts(force: true)
        }
        .refreshable {
            await loadProducts(force: true)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("جارٍ تحميل المنتجات...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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
            Button("أعد المحاولة") {
                Task {
                    await loadProducts(force: true)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("لا توجد منتجات")
                .font(.headline)
            Text("سنضيف منتجات جديدة في هذا التصنيف قريبًا.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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
            errorMessage = nil
        }

        guard hasMore else { return }

        if isLoading || isLoadingMore { return }

        let pageToLoad = nextPage
        let shouldShowInitial = pageToLoad == 1 && products.isEmpty

        if shouldShowInitial {
            isLoading = true
        } else {
            isLoadingMore = true
        }

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

#Preview {
    CategoriesView()
        .environmentObject(FavoritesManager())
}
