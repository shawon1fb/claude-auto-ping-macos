import SwiftUI

/// Advanced settings: duplicate-prevention window, log retention, and
/// maintenance actions such as export, reset, and background uninstall.
struct AdvancedSettingsView: View {
    @Binding var config: SchedulerConfiguration
    let environment: AppEnvironment

    @State private var showResetConfirm = false
    @State private var showUninstallConfirm = false
    @State private var actionMessage: String?

    var body: some View {
        Form {
            Section("Duplicate protection") {
                Stepper(value: cooldownMinutesBinding, in: 1...60) {
                    LabeledContent("Cooldown") {
                        Text("\(Int((config.duplicateCooldown / 60).rounded())) min")
                            .foregroundStyle(.secondary)
                    }
                }
                Text("A message will not be sent again within this window, protecting against relaunches, double timers, and wake events.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Logs") {
                Stepper(value: $config.logRetentionCount, in: 10...1000, step: 10) {
                    LabeledContent("Retention") {
                        Text("\(config.logRetentionCount) entries")
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Export logs…") { exportLogs() }
                Button("Open logs directory") { environment.openLogsDirectory() }
            }

            Section("Maintenance") {
                Button("Reset configuration", role: .destructive) {
                    showResetConfirm = true
                }
                Button("Uninstall background components", role: .destructive) {
                    showUninstallConfirm = true
                }
                if let actionMessage {
                    Text(actionMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Reset all settings to defaults?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) {
                environment.resetConfiguration()
                config = environment.scheduler.configuration
                actionMessage = "Configuration reset to defaults."
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Stop the scheduler and remove the login item?",
            isPresented: $showUninstallConfirm
        ) {
            Button("Uninstall", role: .destructive) {
                environment.uninstallBackgroundComponents()
                config = environment.scheduler.configuration
                actionMessage = "Background components removed. Exported logs are kept."
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This does not delete the app or your exported logs.")
        }
    }

    private var cooldownMinutesBinding: Binding<Int> {
        Binding(
            get: { Int((config.duplicateCooldown / 60).rounded()) },
            set: { config.duplicateCooldown = TimeInterval($0 * 60) }
        )
    }

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "claude-auto-ping-logs.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                let data = try await environment.logStore.exportJSON()
                try data.write(to: url, options: [.atomic])
                actionMessage = "Logs exported to \(url.lastPathComponent)."
            } catch {
                actionMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }
}
