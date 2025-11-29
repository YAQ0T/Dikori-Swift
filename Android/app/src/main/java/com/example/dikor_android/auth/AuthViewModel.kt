package com.example.dikor_android.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.dikor_android.network.AuthService
import com.example.dikor_android.network.NotificationService
import com.example.dikor_android.network.OrderService
import com.example.dikor_android.session.SessionManager
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update

data class AuthUiState(
    val authState: AuthState = AuthState.Loading,
    val name: String = "",
    val phoneNumber: String = "",
    val password: String = "",
    val verificationCode: String = "",
    val statusMessage: String? = null,
    val serviceStatus: String? = null,
    val isWorking: Boolean = false
)

class AuthViewModel(
    private val sessionManager: SessionManager,
    private val authService: AuthService,
    private val notificationService: NotificationService,
    private val orderService: OrderService
) : ViewModel() {

    private val _uiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = _uiState

    init {
        viewModelScope.launch {
            sessionManager.authState.collect { state ->
                _uiState.update { current ->
                    current.copy(
                        authState = state,
                        statusMessage = statusFrom(state) ?: current.statusMessage
                    )
                }
            }
        }
    }

    fun updateName(value: String) {
        _uiState.update { it.copy(name = value) }
    }

    fun updatePhone(value: String) {
        _uiState.update { it.copy(phoneNumber = value) }
    }

    fun updatePassword(value: String) {
        _uiState.update { it.copy(password = value) }
    }

    fun updateVerificationCode(value: String) {
        _uiState.update { it.copy(verificationCode = value) }
    }

    fun login() {
        viewModelScope.launch {
            val phone = uiState.value.phoneNumber
            val password = uiState.value.password
            _uiState.update { it.copy(isWorking = true, statusMessage = "Signing in...") }
            val result = authService.login(phone, password)
            _uiState.update { it.copy(isWorking = false, statusMessage = result.getOrElse { error ->
                error.message ?: "Unable to sign in"
            }) }
        }
    }

    fun register() {
        viewModelScope.launch {
            val name = uiState.value.name.ifBlank { "Customer" }
            val phone = uiState.value.phoneNumber
            val password = uiState.value.password
            _uiState.update { it.copy(isWorking = true, statusMessage = "Creating your account...") }
            val result = authService.register(name, phone, password)
            _uiState.update { it.copy(isWorking = false, statusMessage = result.getOrElse { error ->
                error.message ?: "Registration failed"
            }) }
        }
    }

    fun verifyCode() {
        viewModelScope.launch {
            val code = uiState.value.verificationCode
            val phone = (uiState.value.authState as? AuthState.NeedsVerification)?.phoneNumber
                ?: uiState.value.phoneNumber
            _uiState.update { it.copy(isWorking = true, statusMessage = "Verifying SMS code...") }
            val result = authService.verifySmsCode(phone, code)
            _uiState.update { it.copy(isWorking = false, statusMessage = result.getOrElse { error ->
                error.message ?: "Verification failed"
            }) }
        }
    }

    fun refreshSessionClients() {
        viewModelScope.launch {
            _uiState.update { it.copy(isWorking = true, serviceStatus = null) }
            val notificationSummary = notificationService.refreshPushSubscription()
            val orderSummary = orderService.loadOrders()
            _uiState.update {
                it.copy(
                    isWorking = false,
                    serviceStatus = listOf(notificationSummary, orderSummary).joinToString("\n")
                )
            }
        }
    }

    fun logout() {
        viewModelScope.launch {
            _uiState.update { it.copy(isWorking = true) }
            authService.logout()
            _uiState.update { it.copy(isWorking = false, verificationCode = "") }
        }
    }

    private fun statusFrom(state: AuthState): String? = when (state) {
        AuthState.Loading -> "Restoring session..."
        is AuthState.Authenticated -> state.statusMessage ?: "Session ready for ${state.session.phoneNumber}"
        is AuthState.NeedsVerification -> state.statusMessage ?: "Enter the SMS code we sent to ${state.phoneNumber}."
        is AuthState.Unauthenticated -> state.statusMessage
    }
}

class AuthViewModelFactory(
    private val sessionManager: SessionManager,
    private val authService: AuthService,
    private val notificationService: NotificationService,
    private val orderService: OrderService
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(AuthViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return AuthViewModel(sessionManager, authService, notificationService, orderService) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
