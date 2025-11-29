package com.example.dikor_android.products.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.ListAlt
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.ViewModule
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Divider
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationRail
import androidx.compose.material3.NavigationRailItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.windowsizeclass.WindowSizeClass
import androidx.compose.material3.windowsizeclass.WindowWidthSizeClass
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.dikor_android.products.data.HomeCollectionsService
import com.example.dikor_android.products.data.ProductService
import com.example.dikor_android.products.managers.CartManager
import com.example.dikor_android.products.managers.FavoritesManager
import com.example.dikor_android.products.managers.NotificationsManager
import com.example.dikor_android.products.model.Product
import com.example.dikor_android.session.Session
import com.example.dikor_android.ui.theme.ThemePreference

private enum class ShoppingDestination(val label: String, val icon: ImageVector) {
    HOME(label = "الرئيسية", icon = Icons.Rounded.Home),
    CATALOG(label = "جميع المنتجات", icon = Icons.Rounded.ListAlt),
    CATEGORIES(label = "التصنيفات", icon = Icons.Rounded.ViewModule),
    ACCOUNT(label = "حسابي", icon = Icons.Rounded.Settings)
}

@Composable
fun ShoppingRoot(
    session: Session,
    favoritesManager: FavoritesManager,
    notificationsManager: NotificationsManager,
    cartManager: CartManager,
    productService: ProductService,
    homeCollectionsService: HomeCollectionsService,
    themePreference: ThemePreference,
    onThemePreferenceChange: (ThemePreference) -> Unit,
    windowSizeClass: WindowSizeClass,
    isRefreshing: Boolean,
    serviceStatus: String?,
    onRefreshServices: () -> Unit,
    onLogout: () -> Unit
) {
    val viewModel: ProductsViewModel = viewModel(
        factory = remember {
            ProductsViewModelFactory(
                productService = productService,
                favoritesManager = favoritesManager,
                notificationsManager = notificationsManager,
                homeCollectionsService = homeCollectionsService
            )
        }
    )

    var destination by remember { mutableStateOf(ShoppingDestination.HOME) }
    val useNavigationRail = windowSizeClass.widthSizeClass >= WindowWidthSizeClass.Medium

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Dikori || ديكوري") },
                colors = TopAppBarDefaults.topAppBarColors()
            )
        },
        bottomBar = {
            if (!useNavigationRail) {
                ShoppingNavigationBar(
                    selected = destination,
                    onSelectDestination = { destination = it }
                )
            }
        }
    ) { paddingValues ->
        Row(modifier = Modifier.padding(paddingValues)) {
            if (useNavigationRail) {
                ShoppingNavigationRail(
                    selected = destination,
                    onSelectDestination = { destination = it }
                )
            }

            val contentModifier = if (useNavigationRail) {
                Modifier
                    .padding(horizontal = 12.dp)
                    .weight(1f)
            } else {
                Modifier.fillMaxSize()
            }

            when (destination) {
                ShoppingDestination.HOME -> HighlightsScreen(
                    modifier = contentModifier,
                    favoritesManager = favoritesManager,
                    notificationsManager = notificationsManager,
                    cartManager = cartManager,
                    viewModel = viewModel
                )

                ShoppingDestination.CATALOG -> CatalogScreen(
                    modifier = contentModifier,
                    favoritesManager = favoritesManager,
                    notificationsManager = notificationsManager,
                    cartManager = cartManager,
                    viewModel = viewModel
                )

                ShoppingDestination.CATEGORIES -> CategoriesScreen(
                    modifier = contentModifier,
                    viewModel = viewModel
                )

                ShoppingDestination.ACCOUNT -> AccountSettingsScreen(
                    modifier = contentModifier,
                    session = session,
                    themePreference = themePreference,
                    onThemePreferenceChange = onThemePreferenceChange,
                    isRefreshing = isRefreshing,
                    serviceStatus = serviceStatus,
                    onRefreshServices = onRefreshServices,
                    onLogout = onLogout
                )
            }
        }
    }
}

@Composable
private fun ShoppingNavigationBar(
    selected: ShoppingDestination,
    onSelectDestination: (ShoppingDestination) -> Unit
) {
    NavigationBar {
        ShoppingDestination.entries.forEach { target ->
            NavigationBarItem(
                selected = selected == target,
                onClick = { onSelectDestination(target) },
                icon = { Icon(target.icon, contentDescription = target.label) },
                label = { Text(target.label) }
            )
        }
    }
}

@Composable
private fun ShoppingNavigationRail(
    selected: ShoppingDestination,
    onSelectDestination: (ShoppingDestination) -> Unit
) {
    NavigationRail {
        ShoppingDestination.entries.forEach { target ->
            NavigationRailItem(
                selected = selected == target,
                onClick = { onSelectDestination(target) },
                icon = { Icon(target.icon, contentDescription = target.label) },
                label = { Text(target.label) }
            )
        }
    }
}

@Composable
private fun HighlightsScreen(
    modifier: Modifier,
    favoritesManager: FavoritesManager,
    notificationsManager: NotificationsManager,
    cartManager: CartManager,
    viewModel: ProductsViewModel
) {
    ProductsScreen(
        modifier = modifier,
        showsHomeHighlights = true,
        showsCatalogGrid = false,
        pageSize = 10,
        favoritesManager = favoritesManager,
        notificationsManager = notificationsManager,
        cartManager = cartManager,
        viewModel = viewModel
    )
}

@Composable
private fun CatalogScreen(
    modifier: Modifier,
    favoritesManager: FavoritesManager,
    notificationsManager: NotificationsManager,
    cartManager: CartManager,
    viewModel: ProductsViewModel
) {
    ProductsScreen(
        modifier = modifier,
        showsHomeHighlights = false,
        showsCatalogGrid = true,
        pageSize = 20,
        favoritesManager = favoritesManager,
        notificationsManager = notificationsManager,
        cartManager = cartManager,
        viewModel = viewModel
    )
}

@Composable
private fun CategoriesScreen(
    modifier: Modifier = Modifier,
    viewModel: ProductsViewModel
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        if (uiState.products.isEmpty()) {
            viewModel.loadProducts(force = true, pageSize = 50)
        }
    }

    val categories = remember(uiState.products) {
        uiState.products
            .groupBy { product ->
                product.category?.takeIf { it.isNotBlank() }
                    ?: product.subCategory.takeIf { it.isNotBlank() }
                    ?: "غير مصنف"
            }
            .map { (name, products) -> name to products.sortedBy { it.displayName } }
            .sortedBy { it.first }
    }

    when {
        uiState.isLoading && uiState.products.isEmpty() -> {
            LoadingState(modifier)
        }

        uiState.errorMessage != null && uiState.products.isEmpty() -> {
            ErrorState(modifier, uiState.errorMessage!!)
        }

        else -> {
            LazyColumn(
                modifier = modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.1f)),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                item {
                    Text(
                        text = "تصفح حسب التصنيف",
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp)
                    )
                }

                items(categories) { (name, products) ->
                    CategoryCard(name = name, products = products)
                }

                item { Spacer(Modifier.height(12.dp)) }
            }
        }
    }
}

@Composable
private fun LoadingState(modifier: Modifier = Modifier) {
    Box(modifier = modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator()
    }
}

@Composable
private fun ErrorState(modifier: Modifier = Modifier, message: String) {
    Box(modifier = modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(text = "حدث خطأ", style = MaterialTheme.typography.titleMedium)
            Text(text = message, style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
private fun CategoryCard(name: String, products: List<Product>) {
    Card(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(text = name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Divider()
            products.forEach { product ->
                ProductRow(product = product)
            }
        }
    }
}

@Composable
private fun ProductRow(product: Product) {
    Column(modifier = Modifier.padding(vertical = 6.dp)) {
        Text(text = product.displayName, style = MaterialTheme.typography.bodyLarge)
        Text(text = product.secondaryText, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.secondary)
    }
}

@Composable
private fun AccountSettingsScreen(
    modifier: Modifier = Modifier,
    session: Session,
    themePreference: ThemePreference,
    onThemePreferenceChange: (ThemePreference) -> Unit,
    isRefreshing: Boolean,
    serviceStatus: String?,
    onRefreshServices: () -> Unit,
    onLogout: () -> Unit
) {
    val themeOptions = listOf(
        ThemePreference.SYSTEM to "حسب النظام",
        ThemePreference.LIGHT to "فاتح",
        ThemePreference.DARK to "داكن"
    )

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text("إدارة الحساب", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Text("تسجيل الدخول: ${session.phoneNumber}", fontWeight = FontWeight.Medium)

        serviceStatus?.let { status ->
            Text(text = status, fontWeight = FontWeight.Medium)
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.3f))
        ) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("مظهر التطبيق", style = MaterialTheme.typography.titleMedium)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    themeOptions.forEach { (preference, label) ->
                        FilterChip(
                            selected = themePreference == preference,
                            onClick = { onThemePreferenceChange(preference) },
                            label = { Text(label) }
                        )
                    }
                }
                Text(
                    text = "يتم تطبيق نفس خيارات المظهر المستخدمة في واجهة iOS.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSecondaryContainer
                )
            }
        }

        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("رموز الوصول", style = MaterialTheme.typography.titleMedium)
                Text("Access token\n${session.accessToken}")
                Text("Refresh token\n${session.refreshToken}")
                Text(if (session.isVerified) "SMS verified" else "Awaiting verification")
            }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            Button(
                modifier = Modifier.weight(1f),
                onClick = onRefreshServices,
                enabled = !isRefreshing
            ) { Text(if (isRefreshing) "Refreshing..." else "Refresh clients") }

            Button(
                modifier = Modifier.weight(1f),
                onClick = onLogout
            ) { Text("Logout") }
        }
    }
}
