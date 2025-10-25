import SwiftUI

struct AddToCartButton: View {
    var title: String = "أضف إلى السلة"
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            guard !isLoading && !isDisabled else { return }
            // لمسة اهتزاز خفيفة
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            action()
        } label: {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(isLoading ? "جاري الإضافة..." : title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .frame(minWidth: 180)
            .background(
                // خلفية سوداء أساسية
                Color.black
                    // لمعة داخلية خفيفة
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                // حد أبيض رفيع
                RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.9), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 6)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .opacity((isDisabled || isLoading) ? 0.6 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isPressed)
        }
        .buttonStyle(PressableStyle(isPressed: $isPressed))
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(Text(isLoading ? "جاري الإضافة إلى السلة" : "أضف إلى السلة"))
    }
}

/// ButtonStyle يلتقط حالة الضغط بدون تعارض مع الأنيميشن
private struct PressableStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}

// معاينة/مثال استخدام
struct AddToCartButton_Previews: PreviewProvider {
    struct Demo: View {
        @State private var loading = false
        var body: some View {
            VStack(spacing: 20) {
                AddToCartButton(isLoading: loading) {
                    loading = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        loading = false
                    }
                }

                // حالة تعطيل (لون أبيض/أسود ثابت مع شفافية)
                AddToCartButton(title: "غير متاح", isLoading: false, isDisabled: true) { }
            }
            .padding()
            .background(Color(.systemBackground))
        }
        }
    static var previews: some View { Demo() }
}
