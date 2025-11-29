package com.example.dikor_android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.dikor_android.auth.AuthFlowScreen
import com.example.dikor_android.auth.AuthViewModel
import com.example.dikor_android.auth.AuthViewModelFactory
import com.example.dikor_android.network.AuthService
import com.example.dikor_android.network.NotificationService
import com.example.dikor_android.network.OrderService
import com.example.dikor_android.session.SessionManager
import com.example.dikor_android.ui.theme.DikorAndroidTheme

class MainActivity : ComponentActivity() {
    private val sessionManager by lazy { SessionManager(applicationContext) }
    private val authService by lazy { AuthService(sessionManager) }
    private val notificationService by lazy { NotificationService(sessionManager) }
    private val orderService by lazy { OrderService(sessionManager) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            DikorAndroidTheme {
                AuthRoot(
                    sessionManager = sessionManager,
                    authService = authService,
                    notificationService = notificationService,
                    orderService = orderService
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
    orderService: OrderService
) {
    val factory = remember(sessionManager) {
        AuthViewModelFactory(sessionManager, authService, notificationService, orderService)
    }
    val viewModel: AuthViewModel = viewModel(factory = factory)
    AuthFlowScreen(viewModel)
}
