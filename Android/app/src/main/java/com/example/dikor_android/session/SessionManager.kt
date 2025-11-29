package com.example.dikor_android.session

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.example.dikor_android.auth.AuthState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

private const val DATA_STORE_NAME = "session_preferences"

private val Context.sessionDataStore by preferencesDataStore(DATA_STORE_NAME)

class SessionManager(private val context: Context) {
    private val dataStore = context.sessionDataStore
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val _authState = MutableStateFlow<AuthState>(AuthState.Loading)
    val authState: StateFlow<AuthState> = _authState

    val currentSession: Session?
        get() = (authState.value as? AuthState.Authenticated)?.session

    init {
        observeStore()
    }

    private fun observeStore() {
        scope.launch {
            dataStore.data
                .catch { emit(emptyPreferences()) }
                .map { preferences ->
                    val session = preferences.toSession()
                    val pendingPhone = preferences[PENDING_PHONE]
                    val pendingMessage = preferences[PENDING_MESSAGE]
                    when {
                        session != null -> AuthState.Authenticated(session, preferences[STATUS_MESSAGE])
                        preferences[NEEDS_VERIFICATION] == true && pendingPhone != null ->
                            AuthState.NeedsVerification(pendingPhone, pendingMessage)

                        else -> AuthState.Unauthenticated(preferences[STATUS_MESSAGE])
                    }
                }
                .collect { restoredState ->
                    _authState.value = restoredState
                }
        }
    }

    suspend fun cacheSession(session: Session, message: String? = null) {
        dataStore.edit { preferences ->
            preferences[ACCESS_TOKEN] = session.accessToken
            preferences[REFRESH_TOKEN] = session.refreshToken
            preferences[PHONE_NUMBER] = session.phoneNumber
            preferences[IS_VERIFIED] = session.isVerified
            preferences[NEEDS_VERIFICATION] = false
            preferences.remove(PENDING_PHONE)
            preferences.remove(PENDING_MESSAGE)
            preferences[STATUS_MESSAGE] = message
        }
        _authState.value = AuthState.Authenticated(session, message)
    }

    suspend fun requireVerification(phoneNumber: String, message: String? = null) {
        dataStore.edit { preferences ->
            preferences.remove(ACCESS_TOKEN)
            preferences.remove(REFRESH_TOKEN)
            preferences.remove(IS_VERIFIED)
            preferences[PHONE_NUMBER] = phoneNumber
            preferences[NEEDS_VERIFICATION] = true
            preferences[PENDING_PHONE] = phoneNumber
            preferences[PENDING_MESSAGE] = message
            preferences[STATUS_MESSAGE] = message
        }
        _authState.value = AuthState.NeedsVerification(phoneNumber, message)
    }

    suspend fun clearSession(message: String? = null) {
        dataStore.edit { preferences ->
            preferences.clear()
            if (message != null) {
                preferences[STATUS_MESSAGE] = message
            }
        }
        _authState.value = AuthState.Unauthenticated(message)
    }

    fun authorizationHeaders(): Map<String, String> {
        val session = currentSession ?: return emptyMap()
        return mapOf(
            "Authorization" to "Bearer ${session.accessToken}",
            "X-Refresh-Token" to session.refreshToken,
            "X-Phone" to session.phoneNumber
        )
    }

    private fun Preferences.toSession(): Session? {
        val access = this[ACCESS_TOKEN] ?: return null
        val refresh = this[REFRESH_TOKEN] ?: return null
        val phone = this[PHONE_NUMBER] ?: return null
        val verified = this[IS_VERIFIED] ?: false
        return Session(access, refresh, phone, verified)
    }

    companion object {
        private val ACCESS_TOKEN = stringPreferencesKey("access_token")
        private val REFRESH_TOKEN = stringPreferencesKey("refresh_token")
        private val PHONE_NUMBER = stringPreferencesKey("phone_number")
        private val IS_VERIFIED = booleanPreferencesKey("is_verified")
        private val NEEDS_VERIFICATION = booleanPreferencesKey("needs_verification")
        private val PENDING_PHONE = stringPreferencesKey("pending_phone")
        private val PENDING_MESSAGE = stringPreferencesKey("pending_message")
        private val STATUS_MESSAGE = stringPreferencesKey("status_message")
    }
}
