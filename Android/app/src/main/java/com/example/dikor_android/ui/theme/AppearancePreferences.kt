package com.example.dikor_android.ui.theme

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

private val Context.appearanceDataStore by preferencesDataStore(name = "appearance_preferences")

enum class ThemePreference {
    SYSTEM,
    LIGHT,
    DARK;

    companion object {
        fun fromName(name: String?): ThemePreference {
            return entries.firstOrNull { it.name == name } ?: SYSTEM
        }
    }
}

class AppearancePreferenceStore(private val context: Context) {
    private val preferenceKey = stringPreferencesKey("theme_preference")

    val preferenceFlow = context.appearanceDataStore.data.map { preferences ->
        ThemePreference.fromName(preferences[preferenceKey])
    }

    suspend fun setPreference(preference: ThemePreference) {
        context.appearanceDataStore.edit { preferences ->
            preferences[preferenceKey] = preference.name
        }
    }
}

class AppearanceViewModel(
    private val preferenceStore: AppearancePreferenceStore
) : ViewModel() {
    val preference: StateFlow<ThemePreference> = preferenceStore.preferenceFlow.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = ThemePreference.SYSTEM
    )

    fun updatePreference(preference: ThemePreference) {
        viewModelScope.launch {
            preferenceStore.setPreference(preference)
        }
    }
}

class AppearanceViewModelFactory(
    private val preferenceStore: AppearancePreferenceStore
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(AppearanceViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return AppearanceViewModel(preferenceStore) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
