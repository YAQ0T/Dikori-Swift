package com.example.dikor_android.products.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.ListAlt
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.dikor_android.products.data.HomeCollectionsService
import com.example.dikor_android.products.data.ProductService
import com.example.dikor_android.products.managers.CartManager
import com.example.dikor_android.products.managers.FavoritesManager
import com.example.dikor_android.products.managers.NotificationsManager
import com.example.dikor_android.session.Session

private enum class ShoppingDestination(val label: String, val icon: ImageVector) {
    HOME(label = "الرئيسية", icon = Icons.Rounded.Home),
    CATALOG(label = "جميع المنتجات", icon = Icons.Rounded.ListAlt),
    ACCOUNT(label = "حسابي", icon = Icons.Rounded.Person)
}

@Composable
fun ShoppingRoot(
    session: Session,
    favoritesManager: FavoritesManager,
    notificationsManager: NotificationsManager,
    cartManager: CartManager,
    productService: ProductService,
    homeCollectionsService: HomeCollectionsService,
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

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Dikori || ديكوري") },
                colors = TopAppBarDefaults.topAppBarColors()
            )
        },
        bottomBar = {
            NavigationBar {
                ShoppingDestination.values().forEach { target ->
                    NavigationBarItem(
                        selected = destination == target,
                        onClick = { destination = target },
                        icon = { Icon(target.icon, contentDescription = target.label) },
                        label = { Text(target.label) }
                    )
                }
            }
        }
    ) { paddingValues ->
        when (destination) {
            ShoppingDestination.HOME ->
                ProductsScreen(
                    modifier = Modifier.padding(paddingValues),
                    showsHomeHighlights = true,
                    showsCatalogGrid = false,
                    pageSize = 10,
                    favoritesManager = favoritesManager,
                    notificationsManager = notificationsManager,
                    cartManager = cartManager,
                    viewModel = viewModel
                )

            ShoppingDestination.CATALOG ->
                ProductsScreen(
                    modifier = Modifier.padding(paddingValues),
                    showsHomeHighlights = false,
                    showsCatalogGrid = true,
                    pageSize = 20,
                    favoritesManager = favoritesManager,
                    notificationsManager = notificationsManager,
                    cartManager = cartManager,
                    viewModel = viewModel
                )

            ShoppingDestination.ACCOUNT -> AccountScreen(
                modifier = Modifier.padding(paddingValues),
                session = session,
                isRefreshing = isRefreshing,
                serviceStatus = serviceStatus,
                onRefreshServices = onRefreshServices,
                onLogout = onLogout
            )
        }
    }
}

@Composable
private fun AccountScreen(
    modifier: Modifier = Modifier,
    session: Session,
    isRefreshing: Boolean,
    serviceStatus: String?,
    onRefreshServices: () -> Unit,
    onLogout: () -> Unit
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("Signed in as ${session.phoneNumber}", fontWeight = FontWeight.SemiBold)
        Text("Access token\n${session.accessToken}")
        Text("Refresh token\n${session.refreshToken}")
        Text(if (session.isVerified) "SMS verified" else "Awaiting verification")

        serviceStatus?.let { status ->
            Text(text = status, fontWeight = FontWeight.Medium)
        }

        Spacer(Modifier.height(8.dp))

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
