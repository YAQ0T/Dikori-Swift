import Foundation

struct ProductCategoryGroup: Identifiable, Hashable {
    let mainCategory: String
    let subCategories: [String]

    init(mainCategory: String, subCategories: [String]) {
        self.mainCategory = mainCategory
        self.subCategories = subCategories
    }

    var id: String { mainCategory }

    var displayName: String {
        let trimmed = mainCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "غير مصنف" : trimmed
    }

    var sortedSubCategories: [String] {
        subCategories
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
