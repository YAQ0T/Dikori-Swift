package com.example.dikor_android.products.data

import com.example.dikor_android.products.model.LocalizedText
import com.example.dikor_android.products.model.Product
import com.example.dikor_android.products.model.ProductVariant
import com.example.dikor_android.session.SessionManager
import kotlinx.coroutines.delay

data class ProductQuery(
    val page: Int = 1,
    val limit: Int = 20,
    val search: String? = null
)

class ProductService(sessionManager: SessionManager) {
    private val mockCatalog: List<Product> by lazy {
        buildList {
            repeat(60) { index ->
                val priority = when (index % 4) {
                    0 -> Product.Priority.A
                    1 -> Product.Priority.B
                    2 -> Product.Priority.C
                    else -> Product.Priority.UNKNOWN
                }
                add(
                    Product(
                        id = "product-$index",
                        name = LocalizedText(ar = "منتج رقم ${index + 1}", he = "Product ${index + 1}"),
                        description = LocalizedText(
                            ar = "وصف مختصر للمنتج رقم ${index + 1}",
                            he = "A short blurb for product ${index + 1}"
                        ),
                        category = listOf("أدوات", "منزل", "إلكترونيات", "أزياء")[index % 4],
                        mainCategory = "أساسي ${index % 5}",
                        subCategory = "فرعي ${index % 7}",
                        images = listOf("https://picsum.photos/seed/$index/400/400"),
                        ownershipType = Product.OwnershipType.values()[index % Product.OwnershipType.values().size],
                        priority = priority
                    )
                )
            }
        }
    }

    private val mockVariants: Map<String, List<ProductVariant>> by lazy {
        mockCatalog.associate { product ->
            val variants = List(3) { variantIndex ->
                ProductVariant(
                    id = "variant-${product.id}-$variantIndex",
                    productID = product.id,
                    measure = listOf("S", "M", "L")[variantIndex % 3],
                    measureUnit = "",
                    color = ProductVariant.ColorInfo(
                        name = listOf("أحمر", "أزرق", "أخضر")[variantIndex % 3],
                        code = listOf("#F87171", "#60A5FA", "#34D399")[variantIndex % 3],
                        images = listOf("https://picsum.photos/seed/${product.id}-$variantIndex/300/300")
                    ),
                    price = ProductVariant.PriceInfo(
                        currency = "USD",
                        amount = 20.0 + variantIndex * 4,
                        compareAt = 25.0 + variantIndex * 4,
                        discount = null
                    ),
                    stock = ProductVariant.StockInfo(inStock = 10 + variantIndex, sku = "SKU-${product.id}-$variantIndex"),
                    tags = listOf("tag${variantIndex}", "featured")
                )
            }
            product.id to variants
        }
    }

    suspend fun fetchProducts(query: ProductQuery = ProductQuery()): List<Product> {
        delay(220)
        val filtered = query.search?.takeIf { it.isNotBlank() }?.let { term ->
            val q = term.lowercase()
            mockCatalog.filter {
                it.displayName.lowercase().contains(q) || it.secondaryText.lowercase().contains(q)
            }
        } ?: mockCatalog

        val paged = filtered
            .sortedWith(compareBy<Product> { it.priority.sortOrder }.thenBy { it.displayName })
            .drop((query.page - 1) * query.limit)
            .take(query.limit)

        return paged
    }

    suspend fun fetchProduct(id: String, withVariants: Boolean = true): Pair<Product?, List<ProductVariant>> {
        delay(150)
        val product = mockCatalog.firstOrNull { it.id == id }
        val variants = if (withVariants) mockVariants[id].orEmpty() else emptyList()
        return product to variants
    }
}
