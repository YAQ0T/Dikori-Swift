package com.example.dikor_android.products.managers

import com.example.dikor_android.products.model.CartItem
import com.example.dikor_android.products.model.Product
import com.example.dikor_android.products.model.ProductVariant
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update

class CartManager {
    private val _items = MutableStateFlow<List<CartItem>>(emptyList())
    val items: StateFlow<List<CartItem>> = _items

    val totalQuantity: Int
        get() = _items.value.sumOf { it.quantity }

    fun add(product: Product, variant: ProductVariant? = null, quantity: Int = 1, unitPrice: Double? = null) {
        val existing = _items.value.firstOrNull { it.product.id == product.id && it.variant?.id == variant?.id }
        if (existing == null) {
            _items.update { it + CartItem(product, variant, quantity, unitPrice) }
        } else {
            updateQuantity(existing, existing.quantity + quantity)
        }
    }

    fun remove(item: CartItem) {
        _items.update { list -> list.filterNot { it.product.id == item.product.id && it.variant?.id == item.variant?.id } }
    }

    fun updateQuantity(item: CartItem, quantity: Int) {
        if (quantity <= 0) {
            remove(item)
            return
        }
        _items.update { list ->
            list.map {
                if (it.product.id == item.product.id && it.variant?.id == item.variant?.id) {
                    it.copy(quantity = quantity)
                } else {
                    it
                }
            }
        }
    }

    fun clear() {
        _items.value = emptyList()
    }
}
