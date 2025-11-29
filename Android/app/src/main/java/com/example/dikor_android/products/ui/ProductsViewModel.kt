package com.example.dikor_android.products.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.dikor_android.products.data.HomeCollectionsService
import com.example.dikor_android.products.data.ProductQuery
import com.example.dikor_android.products.data.ProductService
import com.example.dikor_android.products.managers.FavoritesManager
import com.example.dikor_android.products.managers.NotificationsManager
import com.example.dikor_android.products.model.Product
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ProductsUiState(
    val searchText: String = "",
    val activeSearchQuery: String = "",
    val showOnlyFavorites: Boolean = false,
    val products: List<Product> = emptyList(),
    val recommended: List<Product> = emptyList(),
    val newArrivals: List<Product> = emptyList(),
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val isLoadingHighlights: Boolean = false,
    val currentPage: Int = 1,
    val hasMore: Boolean = true,
    val errorMessage: String? = null
)

class ProductsViewModel(
    private val productService: ProductService,
    private val favoritesManager: FavoritesManager,
    private val notificationsManager: NotificationsManager,
    private val homeCollectionsService: HomeCollectionsService
) : ViewModel() {

    private val _uiState = MutableStateFlow(ProductsUiState())
    val uiState: StateFlow<ProductsUiState> = _uiState

    private val sorter: Comparator<Product> = compareBy<Product> { it.priority.sortOrder }
        .thenBy { it.displayName.lowercase() }

    fun updateSearchText(value: String) {
        _uiState.update { it.copy(searchText = value) }
    }

    fun toggleFavoritesFilter() {
        _uiState.update { it.copy(showOnlyFavorites = !it.showOnlyFavorites) }
    }

    fun loadProducts(force: Boolean = false, page: Int? = null, pageSize: Int) {
        val trimmed = uiState.value.searchText.trim()
        var targetPage = page ?: uiState.value.currentPage

        if (force) {
            targetPage = 1
        }

        val effectiveSearch = when {
            force -> trimmed
            uiState.value.products.isEmpty() -> trimmed
            else -> uiState.value.activeSearchQuery
        }

        if (targetPage < 1 || uiState.value.isLoading || uiState.value.isLoadingMore) return

        val shouldShowInitial = uiState.value.products.isEmpty() || force

        _uiState.update {
            it.copy(
                isLoading = shouldShowInitial,
                isLoadingMore = !shouldShowInitial,
                activeSearchQuery = effectiveSearch,
                errorMessage = null,
                hasMore = if (force) true else it.hasMore,
                currentPage = if (force) 1 else it.currentPage,
                products = if (force && trimmed != it.activeSearchQuery) emptyList() else it.products
            )
        }

        viewModelScope.launch {
            try {
                val fetched = productService.fetchProducts(
                    ProductQuery(
                        page = targetPage,
                        limit = pageSize,
                        search = effectiveSearch.takeIf { it.isNotBlank() }
                    )
                )
                _uiState.update { current ->
                    val merged = if (targetPage == 1 || force) {
                        fetched
                    } else {
                        (current.products + fetched).distinctBy { it.id }
                    }
                    val sorted = merged.sortedWith(sorter)
                    favoritesManager.sync(sorted)
                    current.copy(
                        products = sorted,
                        currentPage = targetPage,
                        hasMore = fetched.size == pageSize,
                        isLoading = false,
                        isLoadingMore = false,
                        errorMessage = null
                    )
                }
            } catch (error: Exception) {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        isLoadingMore = false,
                        errorMessage = error.message ?: "Unable to load products"
                    )
                }
            }
        }
    }

    fun loadHighlights() {
        if (_uiState.value.isLoadingHighlights) return
        _uiState.update { it.copy(isLoadingHighlights = true) }
        viewModelScope.launch {
            try {
                val (recommended, newArrivals) = homeCollectionsService.loadHighlights()
                _uiState.update {
                    it.copy(
                        recommended = recommended,
                        newArrivals = newArrivals,
                        isLoadingHighlights = false
                    )
                }
            } catch (_: Exception) {
                _uiState.update { it.copy(isLoadingHighlights = false) }
            }
        }
    }

    fun refreshNotifications() {
        viewModelScope.launch { notificationsManager.loadNotifications() }
    }
}
