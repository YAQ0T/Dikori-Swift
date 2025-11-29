package com.example.dikor_android.products.ui

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.ShoppingBag
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.dikor_android.products.managers.CartManager
import com.example.dikor_android.products.managers.FavoritesManager
import com.example.dikor_android.products.managers.NotificationItem
import com.example.dikor_android.products.managers.NotificationsManager
import com.example.dikor_android.products.model.CartItem
import com.example.dikor_android.products.model.Product
import kotlinx.coroutines.delay

private enum class ActiveSheet { FAVORITES, NOTIFICATIONS, CART }

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun ProductsScreen(
    modifier: Modifier = Modifier,
    showsHomeHighlights: Boolean,
    showsCatalogGrid: Boolean,
    pageSize: Int,
    favoritesManager: FavoritesManager,
    notificationsManager: NotificationsManager,
    cartManager: CartManager,
    viewModel: ProductsViewModel
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val favorites by favoritesManager.favorites.collectAsStateWithLifecycle()
    val cartItems by cartManager.items.collectAsStateWithLifecycle()
    val notifications by notificationsManager.notifications.collectAsStateWithLifecycle()

    var activeSheet by remember { mutableStateOf<ActiveSheet?>(null) }
    var selectedProduct by remember { mutableStateOf<Product?>(null) }

    val filteredProducts = remember(
        uiState.products,
        uiState.activeSearchQuery,
        uiState.searchText,
        uiState.showOnlyFavorites,
        favorites
    ) {
        val effectiveQuery = if (uiState.activeSearchQuery.isNotBlank()) {
            uiState.activeSearchQuery
        } else {
            uiState.searchText.trim()
        }

        uiState.products
            .asSequence()
            .filter { product ->
                val passesFavorites = !uiState.showOnlyFavorites || favorites.contains(product.id)
                val matchesQuery = effectiveQuery.isBlank() ||
                    product.displayName.contains(effectiveQuery, ignoreCase = true) ||
                    product.secondaryText.contains(effectiveQuery, ignoreCase = true)
                passesFavorites && matchesQuery
            }
            .sortedWith(compareBy<Product> { it.priority.sortOrder }.thenBy { it.displayName })
            .toList()
    }

    LaunchedEffect(showsCatalogGrid) {
        if (showsCatalogGrid && uiState.products.isEmpty()) {
            viewModel.loadProducts(force = true, pageSize = pageSize)
        }
    }

    LaunchedEffect(showsHomeHighlights) {
        if (showsHomeHighlights) {
            viewModel.loadHighlights()
        }
    }

    LaunchedEffect(Unit) {
        viewModel.refreshNotifications()
    }

    LaunchedEffect(uiState.searchText) {
        if (!showsCatalogGrid) return@LaunchedEffect
        val trimmed = uiState.searchText.trim()
        delay(300)
        if (trimmed == uiState.searchText.trim()) {
            viewModel.loadProducts(force = true, pageSize = pageSize)
        }
    }

    Scaffold(modifier = modifier) { paddingValues ->
        Column(modifier = Modifier.padding(paddingValues)) {
            HeaderRow(
                searchText = uiState.searchText,
                onSearchTextChange = viewModel::updateSearchText,
                showSearch = showsCatalogGrid,
                favoritesCount = favorites.size,
                unreadNotifications = notifications.count { !it.isRead },
                cartCount = cartManager.totalQuantity,
                showOnlyFavorites = uiState.showOnlyFavorites,
                onToggleFavoritesFilter = viewModel::toggleFavoritesFilter,
                onOpenFavorites = { activeSheet = ActiveSheet.FAVORITES },
                onOpenNotifications = { activeSheet = ActiveSheet.NOTIFICATIONS },
                onOpenCart = { activeSheet = ActiveSheet.CART },
                onSubmitSearch = { viewModel.loadProducts(force = true, pageSize = pageSize) }
            )

            if (showsCatalogGrid && uiState.isLoading && uiState.products.isEmpty()) {
                LoadingState()
            } else if (showsCatalogGrid && uiState.errorMessage != null && uiState.products.isEmpty()) {
                ErrorState(message = uiState.errorMessage!!) {
                    viewModel.loadProducts(force = true, pageSize = pageSize)
                }
            } else if (showsCatalogGrid && filteredProducts.isEmpty()) {
                EmptyState()
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.2f)),
                    verticalArrangement = Arrangement.spacedBy(18.dp)
                ) {
                    if (showsHomeHighlights && uiState.searchText.isBlank() && !uiState.showOnlyFavorites) {
                        item {
                            HomeHighlights(
                                uiState = uiState,
                                onRetry = { viewModel.loadHighlights() },
                                onProductClick = { selectedProduct = it }
                            )
                        }
                    }

                    if (showsCatalogGrid) {
                        item {
                            Text(
                                text = "جميع المنتجات",
                                style = MaterialTheme.typography.titleMedium,
                                modifier = Modifier.padding(horizontal = 20.dp)
                            )
                        }

                        item {
                            LazyVerticalGrid(
                                modifier = Modifier
                                    .height(480.dp)
                                    .padding(horizontal = 16.dp),
                                columns = GridCells.Fixed(2),
                                horizontalArrangement = Arrangement.spacedBy(16.dp),
                                verticalArrangement = Arrangement.spacedBy(16.dp)
                            ) {
                                items(filteredProducts) { product ->
                                    ProductCard(
                                        product = product,
                                        isFavorite = favorites.contains(product.id),
                                        onFavoriteClick = { favoritesManager.toggleFavorite(product) },
                                        onClick = { selectedProduct = product }
                                    )
                                }
                            }
                        }

                        if (uiState.isLoadingMore) {
                            item {
                                Text("جارٍ تحميل المزيد...", modifier = Modifier.padding(12.dp))
                            }
                        }

                        item {
                            PaginationControls(
                                currentPage = uiState.currentPage,
                                hasMore = uiState.hasMore,
                                isLoading = uiState.isLoading || uiState.isLoadingMore,
                                onPrevious = {
                                    viewModel.loadProducts(
                                        page = (uiState.currentPage - 1).coerceAtLeast(1),
                                        pageSize = pageSize
                                    )
                                },
                                onNext = {
                                    viewModel.loadProducts(page = uiState.currentPage + 1, pageSize = pageSize)
                                },
                                onRefresh = { viewModel.loadProducts(force = true, pageSize = pageSize) }
                            )
                        }
                    }
                }
            }
        }
    }

    if (activeSheet != null) {
        ModalBottomSheet(
            onDismissRequest = { activeSheet = null },
            dragHandle = null,
            tonalElevation = 4.dp
        ) {
            when (activeSheet) {
                ActiveSheet.FAVORITES -> FavoritesSheet(favoritesManager)
                ActiveSheet.NOTIFICATIONS -> NotificationsSheet(notificationsManager)
                ActiveSheet.CART -> CartSheet(cartItems) { item -> cartManager.remove(item) }
                null -> Unit
            }
        }
    }

    if (selectedProduct != null) {
        ModalBottomSheet(onDismissRequest = { selectedProduct = null }) {
            ProductDetailsSheet(product = selectedProduct!!, onAddToCart = {
                cartManager.add(selectedProduct!!, quantity = 1, unitPrice = 20.0)
                selectedProduct = null
                activeSheet = ActiveSheet.CART
            })
        }
    }
}

@Composable
private fun HeaderRow(
    searchText: String,
    onSearchTextChange: (String) -> Unit,
    showSearch: Boolean,
    favoritesCount: Int,
    unreadNotifications: Int,
    cartCount: Int,
    showOnlyFavorites: Boolean,
    onToggleFavoritesFilter: () -> Unit,
    onOpenFavorites: () -> Unit,
    onOpenNotifications: () -> Unit,
    onOpenCart: () -> Unit,
    onSubmitSearch: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        IconButton(onClick = onOpenCart) {
            BadgedBox(badge = {
                if (cartCount > 0) Badge { Text(cartCount.toString()) }
            }) {
                Icon(Icons.Rounded.ShoppingBag, contentDescription = "Cart")
            }
        }

        if (showSearch) {
            OutlinedTextField(
                value = searchText,
                onValueChange = onSearchTextChange,
                modifier = Modifier.weight(1f),
                placeholder = { Text("ابحث عن منتج...") },
                singleLine = true,
                leadingIcon = { Icon(Icons.Rounded.Search, contentDescription = null) },
                shape = RoundedCornerShape(50),
                colors = OutlinedTextFieldDefaults.colors(),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                keyboardActions = KeyboardActions(onSearch = { onSubmitSearch() })
            )

            IconButton(onClick = onToggleFavoritesFilter) {
                BadgedBox(badge = {
                    if (favoritesCount > 0) Badge { Text(favoritesCount.toString()) }
                }) {
                    val icon = if (showOnlyFavorites) Icons.Rounded.Favorite else Icons.Rounded.FavoriteBorder
                    Icon(icon, contentDescription = "Favorites")
                }
            }
        } else {
            Spacer(modifier = Modifier.weight(1f))
            IconButton(onClick = onOpenFavorites) {
                BadgedBox(badge = {
                    if (favoritesCount > 0) Badge { Text(favoritesCount.toString()) }
                }) {
                    Icon(Icons.Rounded.Favorite, contentDescription = "Favorites")
                }
            }
        }

        IconButton(onClick = onOpenNotifications) {
            BadgedBox(badge = {
                if (unreadNotifications > 0) Badge { Text(unreadNotifications.toString()) }
            }) {
                Icon(Icons.Rounded.Notifications, contentDescription = "Notifications")
            }
        }
    }
}

@Composable
private fun HomeHighlights(
    uiState: ProductsUiState,
    onRetry: () -> Unit,
    onProductClick: (Product) -> Unit
) {
    Column(modifier = Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text("تصفّح حسب الفئة", style = MaterialTheme.typography.titleMedium)
        HighlightRow(
            title = "منتجات مُقترحة لك",
            products = uiState.recommended,
            isLoading = uiState.isLoadingHighlights,
            onRetry = onRetry,
            onClick = onProductClick
        )
        HighlightRow(
            title = "وصل حديثًا",
            products = uiState.newArrivals,
            isLoading = uiState.isLoadingHighlights,
            onRetry = onRetry,
            onClick = onProductClick
        )
    }
}

@Composable
private fun HighlightRow(
    title: String,
    products: List<Product>,
    isLoading: Boolean,
    onRetry: () -> Unit,
    onClick: (Product) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            TextButton(onClick = onRetry) { Text("تحديث") }
        }

        if (isLoading && products.isEmpty()) {
            Text("جارٍ التحميل...", style = MaterialTheme.typography.bodyMedium)
        } else if (products.isEmpty()) {
            Text("لا توجد منتجات لعرضها الآن", style = MaterialTheme.typography.bodyMedium)
        } else {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                items(products) { product ->
                    ProductCard(
                        product = product,
                        isFavorite = false,
                        onFavoriteClick = { onClick(product) },
                        onClick = { onClick(product) },
                        compact = true
                    )
                }
            }
        }
    }
}

@Composable
private fun ProductCard(
    product: Product,
    isFavorite: Boolean,
    onFavoriteClick: () -> Unit,
    onClick: () -> Unit,
    compact: Boolean = false
) {
    Card(
        modifier = Modifier
            .clickable { onClick() }
            .padding(4.dp),
        shape = RoundedCornerShape(22.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(
                modifier = Modifier
                    .height(if (compact) 120.dp else 180.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(18.dp))
                    .background(Color.LightGray.copy(alpha = 0.4f)),
                contentAlignment = Alignment.Center
            ) {
                Text(text = product.displayName.take(24), fontWeight = FontWeight.SemiBold)
            }

            Text(
                text = product.displayName,
                style = MaterialTheme.typography.titleMedium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = product.secondaryText,
                style = MaterialTheme.typography.bodySmall,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(product.category ?: product.subCategory)
                IconButton(onClick = onFavoriteClick) {
                    val icon = if (isFavorite) androidx.compose.material.icons.Icons.Rounded.Favorite else androidx.compose.material.icons.Icons.Rounded.FavoriteBorder
                    Icon(icon, contentDescription = "Toggle favorite")
                }
            }
        }
    }
}

@Composable
private fun PaginationControls(
    currentPage: Int,
    hasMore: Boolean,
    isLoading: Boolean,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onRefresh: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        OutlinedButton(onClick = onPrevious, enabled = currentPage > 1 && !isLoading) {
            Text("السابق")
        }
        Text("صفحة $currentPage")
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = onRefresh, enabled = !isLoading) { Text("تحديث") }
            Button(onClick = onNext, enabled = hasMore && !isLoading) {
                Text("التالي")
            }
        }
    }
}

@Composable
private fun FavoritesSheet(favoritesManager: FavoritesManager) {
    val favorites by favoritesManager.favorites.collectAsStateWithLifecycle()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("مفضلتي", style = MaterialTheme.typography.titleLarge)
        if (favorites.isEmpty()) {
            Text("لا توجد عناصر مفضلة حتى الآن", style = MaterialTheme.typography.bodyMedium)
        } else {
            favoritesManager.allFavoriteProducts.forEach { product ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(product.displayName, fontWeight = FontWeight.SemiBold)
                        Text(product.secondaryText, style = MaterialTheme.typography.bodySmall)
                    }
                    TextButton(onClick = { favoritesManager.remove(product) }) { Text("إزالة") }
                }
            }
        }
    }
}

@Composable
private fun NotificationsSheet(notificationsManager: NotificationsManager) {
    val notifications by notificationsManager.notifications.collectAsStateWithLifecycle()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("الإشعارات", style = MaterialTheme.typography.titleLarge)
            TextButton(onClick = notificationsManager::markAllRead) { Text("تحديد كمقروء") }
        }

        if (notifications.isEmpty()) {
            Text("لا توجد إشعارات الآن", style = MaterialTheme.typography.bodyMedium)
        } else {
            notifications.forEach { notification ->
                NotificationRow(notification) { notificationsManager.markAsRead(notification.id) }
            }
        }
    }
}

@Composable
private fun NotificationRow(notification: NotificationItem, onMarkRead: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Box(
            modifier = Modifier
                .size(12.dp)
                .clip(CircleShape)
                .background(if (notification.isRead) Color.Gray else Color.Red)
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(notification.title, fontWeight = FontWeight.SemiBold)
            Text(notification.body, style = MaterialTheme.typography.bodySmall, maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
        if (!notification.isRead) {
            TextButton(onClick = onMarkRead) { Text("تم") }
        }
    }
}

@Composable
private fun CartSheet(items: List<CartItem>, onRemove: (CartItem) -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("سلة التسوق", style = MaterialTheme.typography.titleLarge)
        if (items.isEmpty()) {
            Text("السلة فارغة", style = MaterialTheme.typography.bodyMedium)
        } else {
            items.forEach { item ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(item.product.displayName, fontWeight = FontWeight.SemiBold)
                        item.variant?.let { variant ->
                            Text("القياس: ${variant.displayMeasure}", style = MaterialTheme.typography.bodySmall)
                        }
                        Text("الكمية: ${item.quantity}", style = MaterialTheme.typography.bodySmall)
                    }
                    TextButton(onClick = { onRemove(item) }) { Text("إزالة") }
                }
            }
        }
    }
}

@Composable
private fun ProductDetailsSheet(product: Product, onAddToCart: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(product.displayName, style = MaterialTheme.typography.titleLarge)
        Text(product.secondaryText, style = MaterialTheme.typography.bodyMedium)
        Text("الفئة: ${product.category ?: product.subCategory}")
        Button(onClick = onAddToCart) { Text("أضف إلى السلة") }
    }
}

@Composable
private fun LoadingState() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Text("جارٍ تحميل المنتجات...")
    }
}

@Composable
private fun EmptyState() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Text("لا توجد نتائج")
    }
}

@Composable
private fun ErrorState(message: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("تعذر تحميل المنتجات")
        Text(message, style = MaterialTheme.typography.bodySmall)
        Spacer(modifier = Modifier.height(12.dp))
        Button(onClick = onRetry) { Text("أعد المحاولة") }
    }
}
