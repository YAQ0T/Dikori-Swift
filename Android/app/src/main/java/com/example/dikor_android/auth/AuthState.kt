package com.example.dikor_android.auth

import com.example.dikor_android.session.Session

sealed interface AuthState {
    data object Loading : AuthState
    data class Unauthenticated(val statusMessage: String? = null) : AuthState
    data class NeedsVerification(
        val phoneNumber: String,
        val statusMessage: String? = null
    ) : AuthState

    data class Authenticated(val session: Session, val statusMessage: String? = null) : AuthState
}
