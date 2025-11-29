package com.example.dikor_android.products.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.dikor_android.products.data.HomeCollectionsService
import com.example.dikor_android.products.data.ProductService
import com.example.dikor_android.products.managers.FavoritesManager
import com.example.dikor_android.products.managers.NotificationsManager

class ProductsViewModelFactory(
    private val productService: ProductService,
    private val favoritesManager: FavoritesManager,
    private val notificationsManager: NotificationsManager,
    private val homeCollectionsService: HomeCollectionsService
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(ProductsViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return ProductsViewModel(
                productService = productService,
                favoritesManager = favoritesManager,
                notificationsManager = notificationsManager,
                homeCollectionsService = homeCollectionsService
            ) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
