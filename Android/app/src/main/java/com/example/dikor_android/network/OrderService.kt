package com.example.dikor_android.network

import com.example.dikor_android.session.SessionManager
import kotlinx.coroutines.delay

class OrderService(private val sessionManager: SessionManager) {
    suspend fun loadOrders(): String {
        delay(200)
        val headers = sessionManager.authorizationHeaders()
        return if (headers.isEmpty()) {
            "Cannot fetch orders without an authenticated session."
        } else {
            "Orders loaded using ${headers["Authorization"]}"
        }
    }
}
