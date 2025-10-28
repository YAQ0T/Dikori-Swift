import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var appearanceManager: AppearanceManager

    @State private var isPresentingSupportForm = false

    private var appearanceBinding: Binding<AppearanceManager.Preference> {
        Binding(
            get: { appearanceManager.preference },
            set: { appearanceManager.preference = $0 }
        )
    }

    private var user: AuthUserDTO? { sessionManager.session?.user }

    var body: some View {
        NavigationStack {
            List {
                accountSection
                appearanceSection
                supportSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("الإعدادات")
        }
        .sheet(isPresented: $isPresentingSupportForm) {
            NavigationStack {
                SupportFormView()
                    .environmentObject(sessionManager)
            }
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        Section(header: Text("الحساب")) {
            if let user {
                VStack(alignment: .leading, spacing: 8) {
                    Text(user.name)
                        .font(.headline)
                    if let email = user.email, !email.isEmpty {
                        Label(email, systemImage: "envelope.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    if let phone = user.phone, !phone.isEmpty {
                        Label(phone, systemImage: "phone.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Button(role: .destructive) {
                sessionManager.logout()
            } label: {
                HStack {
                    Spacer()
                    Label("تسجيل الخروج", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.headline)
                    Spacer()
                }
            }
            .tint(.red)
        }
    }

    @ViewBuilder
    private var appearanceSection: some View {
        Section(header: Text("المظهر")) {
            Picker("وضع الواجهة", selection: appearanceBinding) {
                ForEach(AppearanceManager.Preference.allCases) { preference in
                    Text(preference.localizedTitle)
                        .tag(preference)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var supportSection: some View {
        Section(header: Text("الدعم")) {
            Button {
                isPresentingSupportForm = true
            } label: {
                HStack {
                    Label("تواصل معنا", systemImage: "envelope.open")
                    Spacer()
                    Image(systemName: "chevron.left")
                        .foregroundColor(.secondary)
                        .imageScale(.small)
                }
            }
        }
    }
}

private struct SupportFormView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var message: String = ""
    @State private var isSubmitting = false
    @State private var alertContext: AlertContext?
    @State private var didPrefillFromSession = false

    @FocusState private var focusedField: Field?

    private let contactService: ContactService

    init(contactService: ContactService = .shared) {
        self.contactService = contactService
    }

    var body: some View {
        Form {
            Section(header: Text("معلومات التواصل")) {
                TextField("الاسم", text: $name)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .name)

                TextField("البريد الإلكتروني", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .email)
            }

            Section(header: Text("رسالتك")) {
                TextEditor(text: $message)
                    .frame(minHeight: 160)
                    .focused($focusedField, equals: .message)
            }

            Section {
                Button(action: submit) {
                    if isSubmitting {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Text("إرسال الرسالة")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!canSubmit || isSubmitting)
            }
        }
        .navigationTitle("الدعم")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("إلغاء") { dismiss() }
            }
            ToolbarItem(placement: .keyboard) {
                Button("تم") { focusedField = nil }
            }
        }
        .onAppear(perform: prefillFromSessionIfNeeded)
        .alert(item: $alertContext) { context in
            Alert(
                title: Text(context.title),
                message: Text(context.message),
                dismissButton: .default(Text("حسناً")) {
                    if context.isSuccess {
                        dismiss()
                    }
                }
            )
        }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard !isSubmitting else { return }
        focusedField = nil
        isSubmitting = true

        Task {
            do {
                let response = try await contactService.submitContactForm(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    message: message.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                await MainActor.run {
                    isSubmitting = false
                    alertContext = AlertContext(
                        title: "تم الإرسال",
                        message: response.message,
                        isSuccess: true
                    )
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    alertContext = AlertContext(
                        title: "حدث خطأ",
                        message: error.localizedDescription,
                        isSuccess: false
                    )
                }
            }
        }
    }

    private func prefillFromSessionIfNeeded() {
        guard !didPrefillFromSession, let user = sessionManager.session?.user else { return }
        didPrefillFromSession = true
        if name.isEmpty {
            name = user.name
        }
        if email.isEmpty, let emailValue = user.email {
            email = emailValue
        }
    }

    private enum Field: Hashable {
        case name
        case email
        case message
    }

    private struct AlertContext: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let isSuccess: Bool
    }
}

#Preview {
    SettingsView()
        .environmentObject(SessionManager.preview())
        .environmentObject(AppearanceManager.preview)
}
