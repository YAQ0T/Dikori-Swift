package com.example.dikor_android.products.managers

import com.example.dikor_android.network.NotificationService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update

data class NotificationItem(
    val id: String,
    val title: String,
    val body: String,
    val isRead: Boolean = false
)

class NotificationsManager(private val notificationService: NotificationService) {
    private val _notifications = MutableStateFlow<List<NotificationItem>>(emptyList())
    val notifications: StateFlow<List<NotificationItem>> = _notifications

    val unreadCount: Int
        get() = _notifications.value.count { !it.isRead }

    suspend fun loadNotifications() {
        val message = notificationService.refreshPushSubscription()
        val demo = List(4) { index ->
            NotificationItem(
                id = "notif-$index",
                title = "تنبيه ${index + 1}",
                body = message
            )
        }
        _notifications.value = demo
    }

    fun markAsRead(id: String) {
        _notifications.update { list ->
            list.map { if (it.id == id) it.copy(isRead = true) else it }
        }
    }

    fun markAllRead() {
        _notifications.update { list -> list.map { it.copy(isRead = true) } }
    }
}
