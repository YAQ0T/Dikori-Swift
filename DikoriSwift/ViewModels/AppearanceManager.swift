import SwiftUI

@MainActor
final class AppearanceManager: ObservableObject {
    enum Preference: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var localizedTitle: String {
            switch self {
            case .system:
                return "النظام"
            case .light:
                return "فاتح"
            case .dark:
                return "داكن"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system:
                return nil
            case .light:
                return .light
            case .dark:
                return .dark
            }
        }
    }

    @Published var preference: Preference {
        didSet {
            activeScheme = preference.colorScheme
            save(preference: preference)
        }
    }

    @Published private(set) var activeScheme: ColorScheme?

    private let storageKey = "appearance.preference"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let stored = userDefaults.string(forKey: storageKey),
           let preference = Preference(rawValue: stored) {
            self.preference = preference
        } else {
            self.preference = .system
        }
        self.activeScheme = preference.colorScheme
    }

    func useSystemAppearance() {
        preference = .system
    }

    func useLightAppearance() {
        preference = .light
    }

    func useDarkAppearance() {
        preference = .dark
    }

    private func save(preference: Preference) {
        userDefaults.set(preference.rawValue, forKey: storageKey)
    }
}

#if DEBUG
extension AppearanceManager {
    static var preview: AppearanceManager {
        let suiteName = "AppearanceManager.preview"
        let defaults: UserDefaults
        if let suiteDefaults = UserDefaults(suiteName: suiteName) {
            suiteDefaults.removePersistentDomain(forName: suiteName)
            defaults = suiteDefaults
        } else {
            defaults = .standard
        }
        let manager = AppearanceManager(userDefaults: defaults)
        manager.preference = .system
        return manager
    }
}
#endif
