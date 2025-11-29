package com.example.dikor_android.network

import com.example.dikor_android.session.SessionManager
import kotlinx.coroutines.delay

class NotificationService(private val sessionManager: SessionManager) {
    suspend fun refreshPushSubscription(): String {
        delay(150)
        val headers = sessionManager.authorizationHeaders()
        return if (headers.isEmpty()) {
            "No session available; notification client is offline."
        } else {
            "Notification client ready with ${headers["Authorization"]}"
        }
    }
}
