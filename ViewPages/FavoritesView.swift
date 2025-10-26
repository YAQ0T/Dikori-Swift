import SwiftUI

struct FavoritesView: View {
    var body: some View {
        NavigationStack {
            FavoritesContent()
                .navigationTitle("مفضلتي")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct FavoritesContent: View {
    @EnvironmentObject private var favoritesManager: FavoritesManager

    private let columns = [
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18)
    ]

    var body: some View {
        Group {
            if favoritesManager.favorites.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(favoritesManager.favorites, id: \.id) { product in
                            NavigationLink {
                                ProductDetails(product: product)
                            } label: {
                                ProductCard(
                                    imageURL: product.primaryImageURL,
                                    title: product.displayName,
                                    subtitle: product.secondaryText,
                                    isFavorite: true
                                ) {
                                    favoritesManager.toggleFavorite(product)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(Color.pink)
            Text("أضِف منتجات إلى مفضلتك")
                .font(.headline)
            Text("استكشف المتجر واضغط على رمز القلب لحفظ ما يعجبك.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    FavoritesView()
        .environmentObject(FavoritesManager())
}
