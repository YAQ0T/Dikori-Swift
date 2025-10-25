import SwiftUI

struct ProductCard: View {
    // مرِّر بياناتك الحقيقية هنا لاحقًا
    let imageURL: URL? = URL(string: "https://i.imgur.com/KKPpSNy.png")
    let title: String = "PCD 1/2 X 30 X 120"
    let subtitle: String = "نصلة سي إن سي ممتازة"

    /// استخدم هذا الإغلاق ليقوم الأب بعملية الـ navigation
    var onTap: () -> Void = {}

    @State private var isFav: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            .frame(height: 187)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

            // التفاصيل
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)

                HStack {
                    Spacer()
                    Button {
                        isFav.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isFav ? "heart.fill" : "heart")
                                .imageScale(.medium)
                            Text(isFav ? "في المفضلة" : "أضِف إلى المفضلة")
                                .font(.subheadline).fontWeight(.semibold)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            (isFav ? Color.red.opacity(0.12) : Color.black.opacity(0.06)),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
        .frame(width: 200, height: 300)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .contentShape(Rectangle()) // يجعل النقر يشمل كل البطاقة
        .onTapGesture {
            onTap()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("\(title)، \(subtitle). اضغط لفتح التفاصيل."))
    }
}

#Preview {
    // مثال معاينة مع تنقّل
    NavigationStack {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack() {
                ProductCard {
                    // مثال تنقل بسيط:
                    // هنا ممكن تستبدله بـ NavigationLink في الأب
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("منتجات")
    }
}
