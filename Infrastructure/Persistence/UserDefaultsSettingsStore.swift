import Foundation
import OSLog

/// `SettingsStore` backed by `UserDefaults`, storing configuration and runtime
/// state as JSON. Decode failures fall back to safe defaults so corrupt or
/// outdated data never crashes the app.
/// `UserDefaults` is thread-safe but not `Sendable`; `@unchecked Sendable`
/// reflects that the stored reference is safe to use across actors.
public final class UserDefaultsSettingsStore: SettingsStore, @unchecked Sendable {
    private enum Key {
        static let configuration = "scheduler.configuration"
        static let state = "scheduler.state"
    }

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: AppInfo.subsystem, category: "SettingsStore")

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadConfiguration() -> SchedulerConfiguration {
        guard let data = defaults.data(forKey: Key.configuration) else {
            return SchedulerConfiguration()
        }
        do {
            let decoded = try JSONDecoder().decode(SchedulerConfiguration.self, from: data)
            return migrate(decoded)
        } catch {
            logger.error("Failed to decode configuration; using defaults: \(error.localizedDescription, privacy: .public)")
            return SchedulerConfiguration()
        }
    }

    public func saveConfiguration(_ configuration: SchedulerConfiguration) {
        do {
            let data = try JSONEncoder().encode(configuration)
            defaults.set(data, forKey: Key.configuration)
        } catch {
            logger.error("Failed to encode configuration: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func loadState() -> SchedulerPersistentState {
        guard let data = defaults.data(forKey: Key.state) else {
            return SchedulerPersistentState()
        }
        do {
            return try JSONDecoder().decode(SchedulerPersistentState.self, from: data)
        } catch {
            logger.error("Failed to decode state; using defaults: \(error.localizedDescription, privacy: .public)")
            return SchedulerPersistentState()
        }
    }

    public func saveState(_ state: SchedulerPersistentState) {
        do {
            let data = try JSONEncoder().encode(state)
            defaults.set(data, forKey: Key.state)
        } catch {
            logger.error("Failed to encode state: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func reset() {
        defaults.removeObject(forKey: Key.configuration)
        defaults.removeObject(forKey: Key.state)
    }

    /// Forward-migrates older configuration versions. New fields already decode
    /// to their defaults thanks to optionality and `init`, so migration mainly
    /// stamps the current version and re-clamps any out-of-range values.
    private func migrate(_ configuration: SchedulerConfiguration) -> SchedulerConfiguration {
        guard configuration.version < SchedulerConfiguration.currentVersion else {
            return configuration
        }
        var migrated = configuration
        migrated.version = SchedulerConfiguration.currentVersion
        logger.info("Migrated configuration to version \(SchedulerConfiguration.currentVersion, privacy: .public)")
        return migrated
    }
}
