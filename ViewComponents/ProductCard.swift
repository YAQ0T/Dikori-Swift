import SwiftUI

struct ProductCard: View {
    let imageURL: URL?
    let title: String
    let subtitle: String
    let isFavorite: Bool
    let onToggleFavorite: (() -> Void)?

    init(
        imageURL: URL? = URL(string: "https://i.imgur.com/KKPpSNy.png"),
        title: String = "PCD 1/2 X 30 X 120",
        subtitle: String = "نصلة سي إن سي ممتازة",
        isFavorite: Bool = false,
        onToggleFavorite: (() -> Void)? = nil
    ) {
        self.imageURL = imageURL
        self.title = title
        self.subtitle = subtitle
        self.isFavorite = isFavorite
        self.onToggleFavorite = onToggleFavorite
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Rectangle().fill(Color.gray.opacity(0.15))
                            ProgressView()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .padding()
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 160)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                if let onToggleFavorite {
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .imageScale(.medium)
                            .font(.title3)
                            .padding(10)
                            .foregroundStyle(isFavorite ? Color.red : Color.primary)
                            .background(
                                Circle()
                                    .fill((isFavorite ? Color.red.opacity(0.15) : Color.black.opacity(0.05)))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .accessibilityLabel(Text(isFavorite ? "إزالة من المفضلة" : "أضِف إلى المفضلة"))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("\(title)، \(subtitle). اضغط لفتح التفاصيل."))
    }
}

#Preview {
    NavigationStack {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                NavigationLink {
                    Text("تفاصيل المنتج")
                } label: {
                    ProductCard()
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("منتجات")
    }
}
