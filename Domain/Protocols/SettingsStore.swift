import Foundation

/// Persists user configuration and scheduler runtime state. Implementations
/// must tolerate missing or corrupt stored data by returning defaults.
public protocol SettingsStore: Sendable {
    func loadConfiguration() -> SchedulerConfiguration
    func saveConfiguration(_ configuration: SchedulerConfiguration)
    func loadState() -> SchedulerPersistentState
    func saveState(_ state: SchedulerPersistentState)
    /// Restores configuration to defaults; runtime state is also cleared.
    func reset()
}
