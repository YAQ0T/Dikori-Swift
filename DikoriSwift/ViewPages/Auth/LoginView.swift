import SwiftUI

struct LoginView: View {
    let onSwitchToRegister: () -> Void
    let onLogin: (_ phone: String, _ password: String) async throws -> Void

    @State private var phone: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isSubmitting: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("تسجيل الدخول")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                TextField("رقم الجوال", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

                SecureField("كلمة المرور", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            }

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
                    Text("دخول")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting || phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)

            Button(action: onSwitchToRegister) {
                Text("مستخدم جديد؟ أنشئ حسابًا")
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
                try await onLogin(phone.trimmingCharacters(in: .whitespacesAndNewlines), password)
                phone = ""
                password = ""
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

#Preview {
    LoginView(onSwitchToRegister: {}, onLogin: { _, _ in })
}
