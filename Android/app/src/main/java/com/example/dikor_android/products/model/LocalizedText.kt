package com.example.dikor_android.products.model

data class LocalizedText(
    val ar: String = "",
    val he: String = ""
) {
    val preferred: String
        get() {
            val trimmedArabic = ar.trim()
            if (trimmedArabic.isNotEmpty()) return trimmedArabic

            val trimmedHebrew = he.trim()
            if (trimmedHebrew.isNotEmpty()) return trimmedHebrew

            return ""
        }
}
