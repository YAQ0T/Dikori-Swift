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
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)

                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    Button {
                        isFav.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isFav ? "heart.fill" : "heart")
                                .imageScale(.medium)
                            Text(isFav ? "في المفضلة" : "أضِف إلى المفضلة")
                                .font(.footnote).fontWeight(.semibold)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            (isFav ? Color.red.opacity(0.12) : Color.black.opacity(0.06)),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 250, alignment: .top)
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
