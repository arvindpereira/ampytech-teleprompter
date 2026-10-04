import Foundation
import Observation

/// Holds the user's prompter settings and persists them to UserDefaults on every change.
@Observable
final class SettingsStore {
    var settings: PrompterSettings {
        didSet {
            guard settings != oldValue else { return }
            save()
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    static let defaultsKey = "prompterSettings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode(PrompterSettings.self, from: data) {
            settings = saved
        } else {
            settings = PrompterSettings()
        }
    }

    func resetToDefaults() {
        settings = PrompterSettings()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
