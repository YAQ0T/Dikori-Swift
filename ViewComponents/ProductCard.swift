import SwiftUI

struct ProductCard: View {
    // مرِّر بياناتك الحقيقية هنا لاحقًا
    let imageURL: URL?
    let title: String
    let subtitle: String

    @State private var isFav: Bool = false

    init(
        imageURL: URL? = URL(string: "https://i.imgur.com/KKPpSNy.png"),
        title: String = "PCD 1/2 X 30 X 120",
        subtitle: String = "نصلة سي إن سي ممتازة",
        isFavorite: Bool = false
    ) {
        self.imageURL = imageURL
        self.title = title
        self.subtitle = subtitle
        _isFav = State(initialValue: isFavorite)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // صورة المنتج
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
            .frame(height: 140)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // التفاصيل
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Button {
                        isFav.toggle()
                    } label: {
                        Image(systemName: isFav ? "heart.fill" : "heart")
                            .imageScale(.medium)
                            .font(.title3)
                            .padding(8)
                            .foregroundStyle(isFav ? Color.red : Color.primary)
                            .background(
                                Circle()
                                    .fill((isFav ? Color.red.opacity(0.15) : Color.black.opacity(0.05)))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(isFav ? "إزالة من المفضلة" : "أضِف إلى المفضلة"))
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("\(title)، \(subtitle). اضغط لفتح التفاصيل."))
    }
}

#Preview {
    // مثال معاينة مع تنقّل
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
