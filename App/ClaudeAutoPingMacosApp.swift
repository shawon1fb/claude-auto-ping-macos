import SwiftUI

/// The app entry point. Presents a `MenuBarExtra` popover and a standard
/// Settings window. There is no main window; the app lives in the menu bar
/// (`LSUIElement`).
@main
struct ClaudeAutoPingMacosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var environment: AppEnvironment

    init() {
        let environment = AppEnvironment()
        environment.bootstrap()
        _environment = State(initialValue: environment)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(environment: environment)
        } label: {
            Label(AppInfo.displayName, systemImage: environment.scheduler.status.menuBarSymbolName)
                .accessibilityLabel(environment.scheduler.status.accessibilityDescription)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(environment: environment)
        }
    }
}
