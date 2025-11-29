package com.example.dikor_android.products.model

data class ProductVariant(
    val id: String,
    val productID: String,
    val measure: String,
    val measureUnit: String = "",
    val measureSlug: String? = null,
    val color: ColorInfo = ColorInfo(),
    val colorSlug: String? = null,
    val price: PriceInfo = PriceInfo(),
    val stock: StockInfo? = null,
    val tags: List<String> = emptyList(),
    val createdAt: String? = null,
    val updatedAt: String? = null
) {
    val displayMeasure: String
        get() = if (measureUnit.isBlank()) measure else "$measure $measureUnit".trim()

    val colorName: String = color.name

    val primaryImage: String?
        get() = color.images.firstOrNull()

    data class ColorInfo(
        val name: String = "",
        val code: String? = null,
        val images: List<String> = emptyList()
    )

    data class PriceInfo(
        val currency: String? = null,
        val amount: Double? = null,
        val compareAt: Double? = null,
        val discount: DiscountInfo? = null
    ) {
        data class DiscountInfo(
            val type: String? = null,
            val value: Double? = null,
            val startAt: String? = null,
            val endAt: String? = null
        )

        val effectiveAmount: Double?
            get() = amount
    }

    data class StockInfo(
        val inStock: Int? = null,
        val sku: String? = null
    )
}
