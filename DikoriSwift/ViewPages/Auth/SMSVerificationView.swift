import SwiftUI

struct SMSVerificationView: View {
    let context: VerificationContext
    let onVerify: (_ code: String) async throws -> Void
    let onSwitchAccount: () -> Void

    @State private var code: String = ""
    @State private var errorMessage: String?
    @State private var isSubmitting: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("التحقق من الجوال")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            if let phone = context.phone, !phone.isEmpty {
                Text("أدخل رمز التحقق المرسل إلى \(phone)")
                    .font(.subheadline)
            }

            if let message = context.message, !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            TextField("رمز التحقق", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            Button(action: submit) {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("تأكيد الرمز")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)

            Button(action: onSwitchAccount) {
                Text("التبديل إلى حساب آخر")
                    .font(.subheadline)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
        .frame(maxWidth: 480)
    }

    private func submit() {
        guard !isSubmitting else { return }
        errorMessage = nil
        isSubmitting = true

        Task {
            do {
                try await onVerify(code.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

#Preview {
    SMSVerificationView(
        context: VerificationContext(userId: "1", phone: "+966512345678", message: ""),
        onVerify: { _ in },
        onSwitchAccount: {}
    )
}
