import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var recommended: [Product] = []
    @Published private(set) var newArrivals: [Product] = []
    @Published private(set) var categories: [CategoriesViewModel.CategorySummary] = []

    @Published private(set) var isLoadingCollections: Bool = false
    @Published private(set) var isLoadingCategories: Bool = false
    @Published var collectionsError: String?
    @Published var categoriesError: String?

    private var hasLoadedCollections = false
    private var hasLoadedCategories = false

    func loadInitialDataIfNeeded() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await self?.loadHomeCollections(force: false)
            }

            group.addTask { [weak self] in
                await self?.loadCategoriesPreview(force: false)
            }
        }
    }

    func refreshHighlights() async {
        hasLoadedCollections = false
        hasLoadedCategories = false
        await loadInitialDataIfNeeded()
    }

    func reloadCollections() async {
        await loadHomeCollections(force: true)
    }

    func reloadCategories() async {
        await loadCategoriesPreview(force: true)
    }

    private func loadHomeCollections(force: Bool) async {
        if isLoadingCollections { return }
        if hasLoadedCollections && !force { return }

        isLoadingCollections = true
        collectionsError = nil
        defer { isLoadingCollections = false }

        do {
            let response = try await HomeCollectionsService.shared.fetchCollections()
            recommended = response.recommended
            newArrivals = response.newArrivals
            hasLoadedCollections = true
        } catch {
            collectionsError = error.localizedDescription
        }
    }

    private func loadCategoriesPreview(force: Bool) async {
        if isLoadingCategories { return }
        if hasLoadedCategories && !force { return }

        isLoadingCategories = true
        categoriesError = nil
        defer { isLoadingCategories = false }

        do {
            let fetched = try await ProductService.shared.fetchProducts(
                query: ProductQuery(page: 1, limit: 200)
            )
            categories = buildSummaries(from: fetched)
            hasLoadedCategories = true
        } catch {
            categoriesError = error.localizedDescription
        }
    }

    private func buildSummaries(from products: [Product]) -> [CategoriesViewModel.CategorySummary] {
        var map: [String: Set<String>] = [:]

        for product in products {
            let main = product.mainCategory.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !main.isEmpty else { continue }

            let sub = product.subCategory.trimmingCharacters(in: .whitespacesAndNewlines)
            var set = map[main, default: []]
            if !sub.isEmpty {
                set.insert(sub)
            }
            map[main] = set
        }

        let summaries = map.map { name, subcategories in
            CategoriesViewModel.CategorySummary(
                name: name,
                subcategories: Array(subcategories)
            )
        }
        .sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        return Array(summaries.prefix(8))
    }
}
