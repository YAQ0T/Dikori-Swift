package com.example.dikor_android.products.managers

import com.example.dikor_android.products.model.Product
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update

class FavoritesManager {
    private val _favorites = MutableStateFlow<Set<String>>(emptySet())
    val favorites: StateFlow<Set<String>> = _favorites

    private val cachedProducts = mutableMapOf<String, Product>()

    val allFavoriteProducts: List<Product>
        get() = _favorites.value.mapNotNull { cachedProducts[it] }

    fun isFavorite(product: Product): Boolean = _favorites.value.contains(product.id)

    fun toggleFavorite(product: Product) {
        if (isFavorite(product)) {
            remove(product)
        } else {
            add(product)
        }
    }

    fun add(product: Product) {
        cachedProducts[product.id] = product
        _favorites.update { it + product.id }
    }

    fun remove(product: Product) {
        _favorites.update { it - product.id }
    }

    fun sync(products: List<Product>) {
        products.forEach { product ->
            if (_favorites.value.contains(product.id)) {
                cachedProducts[product.id] = product
            }
        }
    }
}
