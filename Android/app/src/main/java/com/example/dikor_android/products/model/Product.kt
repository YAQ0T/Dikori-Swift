package com.example.dikor_android.products.model

data class Product(
    val id: String,
    val name: LocalizedText = LocalizedText(),
    val description: LocalizedText = LocalizedText(),
    val category: String? = null,
    val mainCategory: String = "",
    val subCategory: String = "",
    val images: List<String> = emptyList(),
    val ownershipType: OwnershipType = OwnershipType.UNKNOWN,
    val priority: Priority = Priority.UNKNOWN,
    val createdAt: String? = null,
    val updatedAt: String? = null
) {
    val displayName: String = name.preferred

    val secondaryText: String
        get() {
            val trimmedDescription = description.preferred.trim()
            if (trimmedDescription.isNotEmpty()) return trimmedDescription
            if (!category.isNullOrBlank()) return category
            return subCategory
        }

    val primaryImage: String?
        get() = images.firstOrNull()

    enum class OwnershipType { OURS, LOCAL, UNKNOWN }

    enum class Priority(val sortOrder: Int) {
        A(0), B(1), C(2), UNKNOWN(3)
    }
}
