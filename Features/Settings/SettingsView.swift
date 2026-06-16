import SwiftUI

/// The Settings window, organized into the General, Automation, Permissions,
/// Advanced, and Logs sections. A single local copy of the configuration is the
/// source of truth for the form; changes are pushed to the scheduler on edit.
struct SettingsView: View {
    let environment: AppEnvironment
    @State private var config: SchedulerConfiguration

    init(environment: AppEnvironment) {
        self.environment = environment
        _config = State(initialValue: environment.scheduler.configuration)
    }

    var body: some View {
        TabView {
            GeneralSettingsView(config: $config, environment: environment)
                .tabItem { Label("General", systemImage: "gearshape") }

            AutomationSettingsView(config: $config, environment: environment)
                .tabItem { Label("Automation", systemImage: "wand.and.stars") }

            PermissionSettingsView(config: $config, environment: environment)
                .tabItem { Label("Permissions", systemImage: "lock.shield") }

            AdvancedSettingsView(config: $config, environment: environment)
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }

            LogsView(environment: environment)
                .tabItem { Label("Logs", systemImage: "list.bullet.rectangle") }
        }
        .frame(width: 500, height: 460)
        .onChange(of: config) { _, newValue in
            environment.updateConfiguration(newValue)
        }
        .onChange(of: environment.scheduler.configuration) { _, newValue in
            // Keep the form in sync if the configuration changes elsewhere
            // (for example, a reset), without clobbering in-progress edits.
            if newValue != config {
                config = newValue
            }
        }
    }
}
