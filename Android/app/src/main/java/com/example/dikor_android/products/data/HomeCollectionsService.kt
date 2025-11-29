package com.example.dikor_android.products.data

import com.example.dikor_android.products.model.Product
import com.example.dikor_android.session.SessionManager
import kotlinx.coroutines.delay

class HomeCollectionsService(private val sessionManager: SessionManager) {
    private val productService = ProductService(sessionManager)

    suspend fun loadHighlights(): Pair<List<Product>, List<Product>> {
        delay(180)
        val base = productService.fetchProducts(ProductQuery(page = 1, limit = 200))
        val recommended = base.shuffled().take(8)
        val newArrivals = base.sortedByDescending { it.createdAt ?: it.id }.take(8)
        return recommended to newArrivals
    }
}
