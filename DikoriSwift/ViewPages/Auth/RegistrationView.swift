import SwiftUI

struct RegistrationView: View {
    let onSwitchToLogin: () -> Void
    let onSignup: (_ name: String, _ phone: String, _ password: String) async throws -> Void

    @State private var fullName: String = ""
    @State private var phone: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String?
    @State private var isSubmitting: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("إنشاء حساب")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                TextField("الاسم الكامل", text: $fullName)
                    .textContentType(.name)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

                TextField("رقم الجوال", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

                SecureField("كلمة المرور", text: $password)
                    .textContentType(.newPassword)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

                SecureField("تأكيد كلمة المرور", text: $confirmPassword)
                    .textContentType(.newPassword)
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
                    Text("إنشاء الحساب")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isFormValid || isSubmitting)

            Button(action: onSwitchToLogin) {
                Text("لديك حساب؟ سجّل الدخول")
                    .font(.subheadline)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
        .frame(maxWidth: 480)
    }

    private var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        password.count >= 6 &&
        password == confirmPassword
    }

    private func submit() {
        guard isFormValid, !isSubmitting else { return }
        errorMessage = nil
        isSubmitting = true

        Task {
            do {
                try await onSignup(
                    fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                    phone.trimmingCharacters(in: .whitespacesAndNewlines),
                    password
                )
                password = ""
                confirmPassword = ""
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

#Preview {
    RegistrationView(onSwitchToLogin: {}, onSignup: { _, _, _ in })
}
