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
    @EnvironmentObject private var notificationsManager: NotificationsManager

    @State private var searchText: String = ""
    @FocusState private var isSearching: Bool
    @State private var showOnlyFavorites: Bool = false
    @State private var activeSheet: ActiveSheet?

    @State private var products: [Product] = []
    @State private var isLoading: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var errorMessage: String?
    @State private var nextPage: Int = 1
    @State private var hasMore: Bool = true
    @State private var activeSearchQuery: String = ""
    @State private var searchDebounceTask: Task<Void, Never>?

    private let pageSize: Int = 100
    private let columns = [
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18)
    ]

    private enum ActiveSheet: Identifiable {
        case favorites, notifications

        var id: Int {
            switch self {
            case .favorites: return 0
            case .notifications: return 1
            }
        }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var favoritesCount: Int {
        favoritesManager.allFavoriteIDs.count
    }

    private var unreadNotificationsCount: Int {
        notificationsManager.notifications.filter { !$0.isRead }.count
    }

    private var filteredProducts: [Product] {
        var base = products

        let query = activeSearchQuery.isEmpty ? trimmedSearchText : activeSearchQuery

        if !query.isEmpty {
            let lowercasedQuery = query.lowercased()
            base = base.filter { product in
                product.displayName.lowercased().contains(lowercasedQuery) ||
                product.secondaryText.lowercased().contains(lowercasedQuery)
            }
        }

        if showOnlyFavorites {
            base = base.filter { favoritesManager.allFavoriteIDs.contains($0.id) }
        }

        return base
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if isLoading && products.isEmpty {
                loadingState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, products.isEmpty {
                errorState(message: errorMessage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredProducts.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .center, spacing: 20) {
                        ForEach(filteredProducts) { product in
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
        .background(Color(.systemGroupedBackground))
        .navigationTitle(subCategory)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProducts(force: true)
            await notificationsManager.loadNotifications()
        }
        .refreshable {
            await loadProducts(force: true)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .favorites:
                NavigationStack {
                    FavoritesContent()
                        .environmentObject(favoritesManager)
                        .navigationTitle("مفضلتي")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("إغلاق") { activeSheet = nil }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)

            case .notifications:
                NavigationStack {
                    NotificationsContent()
                        .environmentObject(notificationsManager)
                        .navigationTitle("الإشعارات")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("إغلاق") { activeSheet = nil }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: searchText) { _, newValue in
            searchDebounceTask?.cancel()
            searchDebounceTask = nil

            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                if !activeSearchQuery.isEmpty {
                    searchDebounceTask = Task {
                        await loadProducts(force: true)
                    }
                }
                return
            }

            guard trimmed != activeSearchQuery else { return }

            let task = Task { [trimmed] in
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }

                let isCurrent = await MainActor.run { self.trimmedSearchText == trimmed }
                guard isCurrent else { return }

                await loadProducts(force: true)
            }

            searchDebounceTask = task
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").opacity(0.6)
                    TextField("ابحث عن منتج...", text: $searchText)
                        .focused($isSearching)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .submitLabel(.search)
                        .onSubmit {
                            searchDebounceTask?.cancel()
                            searchDebounceTask = nil
                            searchDebounceTask = Task {
                                await loadProducts(force: true)
                            }
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())

                Menu {
                    Button {
                        showOnlyFavorites.toggle()
                    } label: {
                        Label(
                            showOnlyFavorites ? "عرض كل المنتجات" : "عرض المفضلة فقط",
                            systemImage: showOnlyFavorites ? "rectangle.stack" : "heart.text.square"
                        )
                    }

                    if favoritesCount > 0 {
                        Button {
                            activeSheet = .favorites
                        } label: {
                            Label("إدارة المفضلة (\(favoritesCount))", systemImage: "heart.circle")
                        }
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: showOnlyFavorites ? "heart.circle.fill" : "heart")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)

                        if favoritesCount > 0 {
                            Text("\(favoritesCount)")
                                .font(.caption2.bold())
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(Color.pink.opacity(0.9))
                                )
                                .foregroundStyle(Color.white)
                                .offset(x: 10, y: -8)
                        }
                    }
                }
                .accessibilityLabel(Text("خيارات المفضلة"))

                Button {
                    activeSheet = .notifications
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: unreadNotificationsCount > 0 ? "bell.badge.fill" : "bell")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)

                        if unreadNotificationsCount > 0 {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .offset(x: 8, y: -8)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(unreadNotificationsCount > 0 ? "إشعارات جديدة" : "الإشعارات"))
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemBackground).opacity(0.98))

            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
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
        let trimmedQuery = trimmedSearchText
        let previousQuery = activeSearchQuery

        if force {
            nextPage = 1
            hasMore = true
            if trimmedQuery != previousQuery {
                products = []
            }
            activeSearchQuery = trimmedQuery
            errorMessage = nil
        } else if nextPage == 1 && products.isEmpty {
            activeSearchQuery = trimmedQuery
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
                subCategory: subCategory,
                search: activeSearchQuery.isEmpty ? nil : activeSearchQuery
            )
            let fetched = try await ProductService.shared.fetchProducts(query: query)
            let sanitizedBatch = [Product]().mergingUnique(with: fetched)

            if pageToLoad == 1 {
                products = sanitizedBatch
            } else {
                products = products.mergingUnique(with: sanitizedBatch)
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
        let filtered = filteredProducts
        guard let index = filtered.firstIndex(of: product) else { return }

        let thresholdIndex = filtered.index(
            filtered.endIndex,
            offsetBy: -6,
            limitedBy: filtered.startIndex
        ) ?? filtered.startIndex

        if index >= thresholdIndex {
            await loadProducts()
        }
    }
}

#Preview {
    CategoriesView()
        .environmentObject(FavoritesManager())
        .environmentObject(NotificationsManager())
}
