//
//  Products.swift
//  DikoriLearn
//
//  Created by Ahmad Salous on 19/10/2025.
//

import SwiftUI

public struct Products: View {
    @EnvironmentObject private var favoritesManager: FavoritesManager
    @EnvironmentObject private var notificationsManager: NotificationsManager
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @EnvironmentObject private var cartManager: CartManager

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

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // أعمدة الشبكة (عمودان)
    private let columns = [
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18),
    ]

    private enum ActiveSheet: Identifiable {
        case favorites, notifications, cart

        var id: Int {
            switch self {
            case .favorites: return 0
            case .notifications: return 1
            case .cart: return 2
            }
        }
    }

    private var favoritesCount: Int {
        favoritesManager.allFavoriteIDs.count
    }

    private var unreadNotificationsCount: Int {
        notificationsManager.notifications.filter { !$0.isRead }.count
    }

    // تصفية حسب البحث + المفضلة
    private var filteredProducts: [Product] {
        var base = products

        let effectiveQuery: String
        if !activeSearchQuery.isEmpty {
            effectiveQuery = activeSearchQuery
        } else {
            effectiveQuery = trimmedSearchText
        }

        if !effectiveQuery.isEmpty {
            let q = effectiveQuery.lowercased()
            base = base.filter { product in
                product.displayName.lowercased().contains(q) ||
                product.secondaryText.lowercased().contains(q)
            }
        }

        if showOnlyFavorites {
            base = base.filter { favoritesManager.allFavoriteIDs.contains($0.id) }
        }

        return base
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                if isLoading && products.isEmpty {
                    loadingState
                } else if let errorMessage, products.isEmpty {
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
                                    ProductDetails(product: product)
                                } label: {
                                    // استخدم ProductCard كما بنيناه بدون سعر/سلة
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
            .navigationTitle("Dikori || ديكوري ")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .task {
                await loadProducts()
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

                case .cart:
                    NavigationStack {
                        CartView()
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
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                cartButton

                // شريط البحث بكبسولة
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
                .frame(maxWidth: .infinity)

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

            // خط سفلي (border-bottom)
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
        }
    }

    private var cartButton: some View {
        Button {
            activeSheet = .cart
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: cartManager.totalItems > 0 ? "cart.fill" : "cart")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)

                if cartManager.totalItems > 0 {
                    Text("\(cartManager.totalItems)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Color.accentColor.opacity(0.9))
                        )
                        .foregroundStyle(Color.white)
                        .offset(x: 10, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text(
                cartManager.totalItems > 0
                    ? "السلة تحتوي \(cartManager.totalItems) عناصر"
                    : "السلة"
            )
        )
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
    Products()
        .environmentObject(FavoritesManager())
        .environmentObject(NotificationsManager())
        .environmentObject(CartManager.preview())
}
