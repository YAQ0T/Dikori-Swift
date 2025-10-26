import Foundation
import SwiftUI

@MainActor
final class FavoritesManager: ObservableObject {
    @Published private(set) var favorites: [Product] = []

    private let storageKey = "favoriteProductIDs"
    private var favoriteIDs: Set<String>
    private var favoritesMap: [String: Product]

    init(userDefaults: UserDefaults = .standard) {
        if let stored = userDefaults.array(forKey: storageKey) as? [String] {
            self.favoriteIDs = Set(stored)
        } else {
            self.favoriteIDs = []
        }
        self.favoritesMap = [:]
        self.userDefaults = userDefaults
    }

    private let userDefaults: UserDefaults

    var allFavoriteIDs: Set<String> { favoriteIDs }

    func isFavorite(_ product: Product) -> Bool {
        favoriteIDs.contains(product.id)
    }

    func toggleFavorite(_ product: Product) {
        if isFavorite(product) {
            remove(product)
        } else {
            add(product)
        }
    }

    func add(_ product: Product) {
        favoriteIDs.insert(product.id)
        favoritesMap[product.id] = product
        persist()
        rebuildFavoritesList()
    }

    func remove(_ product: Product) {
        favoriteIDs.remove(product.id)
        favoritesMap.removeValue(forKey: product.id)
        persist()
        rebuildFavoritesList()
    }

    func removeFavorite(withId id: String) {
        favoriteIDs.remove(id)
        favoritesMap.removeValue(forKey: id)
        persist()
        rebuildFavoritesList()
    }

    func sync(with products: [Product]) {
        guard !products.isEmpty else { return }

        for product in products where favoriteIDs.contains(product.id) {
            favoritesMap[product.id] = product
        }

        rebuildFavoritesList()
    }

    private func persist() {
        userDefaults.set(Array(favoriteIDs), forKey: storageKey)
    }

    private func rebuildFavoritesList() {
        favorites = favoritesMap.values.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}
