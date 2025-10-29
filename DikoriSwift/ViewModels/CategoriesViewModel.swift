import Foundation

@MainActor
final class CategoriesViewModel: ObservableObject {
    struct CategorySummary: Identifiable, Hashable {
        struct SubcategorySummary: Identifiable, Hashable {
            let id: String
            let name: String

            init(name: String) {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                self.id = trimmed
                self.name = trimmed
            }
        }

        let id: String
        let name: String
        let subcategories: [SubcategorySummary]

        init(name: String, subcategories: [String]) {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            self.id = trimmedName
            self.name = trimmedName
            self.subcategories = subcategories
                .map(SubcategorySummary.init(name:))
                .sorted { lhs, rhs in
                    lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
        }
    }

    @Published private(set) var categories: [CategorySummary] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    private var nextPage: Int = 1
    private var hasMore: Bool = true
    private let pageSize: Int = 200
    private var categoryMap: [String: Set<String>] = [:]

    func loadIfNeeded() async {
        guard categories.isEmpty else { return }
        await loadCategories(force: true)
    }

    func reload() async {
        await loadCategories(force: true)
    }

    private func loadCategories(force: Bool) async {
        if isLoading { return }

        if force {
            nextPage = 1
            hasMore = true
            categoryMap = [:]
            categories = []
            errorMessage = nil
        }

        guard hasMore else { return }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            while hasMore {
                try Task.checkCancellation()

                let query = ProductQuery(
                    page: nextPage,
                    limit: pageSize
                )

                let fetched = try await ProductService.shared.fetchProducts(query: query)
                integrate(products: fetched)
                rebuildCategories()

                if fetched.count < pageSize {
                    hasMore = false
                } else {
                    nextPage += 1
                }

                if fetched.isEmpty {
                    break
                }
            }
        } catch is CancellationError {
            // Ignore cancellations.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func integrate(products: [Product]) {
        guard !products.isEmpty else { return }

        for product in products {
            let main = product.mainCategory.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !main.isEmpty else { continue }

            let sub = product.subCategory.trimmingCharacters(in: .whitespacesAndNewlines)

            var set = categoryMap[main, default: []]
            if !sub.isEmpty {
                set.insert(sub)
            }
            categoryMap[main] = set
        }
    }

    private func rebuildCategories() {
        let summaries = categoryMap.map { key, value -> CategorySummary in
            CategorySummary(name: key, subcategories: Array(value))
        }

        categories = summaries.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
