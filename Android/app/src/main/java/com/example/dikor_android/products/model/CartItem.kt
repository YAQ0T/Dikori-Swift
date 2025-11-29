package com.example.dikor_android.products.model

data class CartItem(
    val product: Product,
    val variant: ProductVariant? = null,
    val quantity: Int = 1,
    val unitPrice: Double? = null
) {
    val totalPrice: Double?
        get() = unitPrice?.let { it * quantity }
}
