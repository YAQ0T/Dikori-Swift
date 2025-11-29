package com.example.dikor_android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.dikor_android.auth.AuthFlowScreen
import com.example.dikor_android.auth.AuthViewModel
import com.example.dikor_android.auth.AuthViewModelFactory
import com.example.dikor_android.network.AuthService
import com.example.dikor_android.network.NotificationService
import com.example.dikor_android.network.OrderService
import com.example.dikor_android.ui.theme.AppearancePreferenceStore
import com.example.dikor_android.ui.theme.AppearanceViewModel
import com.example.dikor_android.ui.theme.AppearanceViewModelFactory
import com.example.dikor_android.products.data.HomeCollectionsService
import com.example.dikor_android.products.data.ProductService
import com.example.dikor_android.products.managers.CartManager
import com.example.dikor_android.products.managers.FavoritesManager
import com.example.dikor_android.products.managers.NotificationsManager
import com.example.dikor_android.session.SessionManager
import com.example.dikor_android.ui.theme.DikorAndroidTheme
import com.example.dikor_android.ui.theme.ThemePreference
import androidx.compose.material3.windowsizeclass.ExperimentalMaterial3WindowSizeClassApi
import androidx.compose.material3.windowsizeclass.calculateWindowSizeClass
import androidx.compose.material3.windowsizeclass.WindowSizeClass
import androidx.lifecycle.compose.collectAsStateWithLifecycle

class MainActivity : ComponentActivity() {
    private val sessionManager by lazy { SessionManager(applicationContext) }
    private val authService by lazy { AuthService(sessionManager) }
    private val notificationService by lazy { NotificationService(sessionManager) }
    private val orderService by lazy { OrderService(sessionManager) }
    private val appearancePreferenceStore by lazy { AppearancePreferenceStore(applicationContext) }

    @OptIn(ExperimentalMaterial3WindowSizeClassApi::class)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val windowSizeClass = calculateWindowSizeClass(this)
        setContent {
            val appearanceViewModel: AppearanceViewModel = viewModel(
                factory = AppearanceViewModelFactory(appearancePreferenceStore)
            )
            val themePreference by appearanceViewModel.preference.collectAsStateWithLifecycle()
            val darkTheme = when (themePreference) {
                ThemePreference.SYSTEM -> isSystemInDarkTheme()
                ThemePreference.DARK -> true
                ThemePreference.LIGHT -> false
            }

            DikorAndroidTheme(darkTheme = darkTheme, dynamicColor = themePreference == ThemePreference.SYSTEM) {
                val favoritesManager = remember { FavoritesManager() }
                val notificationsManager = remember { NotificationsManager(notificationService) }
                val cartManager = remember { CartManager() }
                val productService = remember(sessionManager) { ProductService(sessionManager) }
                val homeCollectionsService = remember(sessionManager) { HomeCollectionsService(sessionManager) }

                AuthRoot(
                    sessionManager = sessionManager,
                    authService = authService,
                    notificationService = notificationService,
                    orderService = orderService,
                    favoritesManager = favoritesManager,
                    notificationsManager = notificationsManager,
                    cartManager = cartManager,
                    productService = productService,
                    homeCollectionsService = homeCollectionsService,
                    themePreference = themePreference,
                    onThemePreferenceChange = appearanceViewModel::updatePreference,
                    windowSizeClass = windowSizeClass
                )
            }
        }
    }
}

@Composable
private fun AuthRoot(
    sessionManager: SessionManager,
    authService: AuthService,
    notificationService: NotificationService,
    orderService: OrderService,
    favoritesManager: FavoritesManager,
    notificationsManager: NotificationsManager,
    cartManager: CartManager,
    productService: ProductService,
    homeCollectionsService: HomeCollectionsService,
    themePreference: ThemePreference,
    onThemePreferenceChange: (ThemePreference) -> Unit,
    windowSizeClass: WindowSizeClass
) {
    val factory = remember(sessionManager) {
        AuthViewModelFactory(sessionManager, authService, notificationService, orderService)
    }
    val viewModel: AuthViewModel = viewModel(factory = factory)
    AuthFlowScreen(
        viewModel = viewModel,
        favoritesManager = favoritesManager,
        notificationsManager = notificationsManager,
        cartManager = cartManager,
        productService = productService,
        homeCollectionsService = homeCollectionsService,
        themePreference = themePreference,
        onThemePreferenceChange = onThemePreferenceChange,
        windowSizeClass = windowSizeClass
    )
}
