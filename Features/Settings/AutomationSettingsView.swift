import SwiftUI

/// Automation settings: where Claude is, how the new chat is opened, the timing
/// delays, and the test actions.
struct AutomationSettingsView: View {
    @Binding var config: SchedulerConfiguration
    let environment: AppEnvironment

    @State private var detectionResult: String?
    @State private var isTesting = false
    @State private var testResult: String?

    var body: some View {
        Form {
            Section("Claude application") {
                LabeledContent("Path") {
                    Text(config.claudeAppPath ?? "Auto-detected")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack {
                    Button("Detect Claude") { detect() }
                    Button("Choose Claude App…") { choose() }
                    if config.claudeAppPath != nil {
                        Button("Clear") { config.claudeAppPath = nil }
                    }
                }
                if let detectionResult {
                    Text(detectionResult)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("New chat shortcut") {
                ShortcutEditor(shortcut: $config.newChatShortcut)
                Text("Current: \(config.newChatShortcut.displayString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Timing") {
                DelayStepper(title: "Launch delay", seconds: $config.launchDelay)
                DelayStepper(title: "New-chat delay", seconds: $config.newChatDelay)
                DelayStepper(title: "Send delay", seconds: $config.sendDelay)
                Toggle("Automatically press Return to send", isOn: $config.pressReturnAutomatically)
            }

            Section("Test") {
                HStack {
                    Button("Dry-run test") { runTest(dryRun: true) }
                        .help("Performs every step except pressing Return.")
                    Button("Full send test") { runTest(dryRun: false) }
                        .help("Sends the configured message now.")
                    if isTesting { ProgressView().controlSize(.small) }
                }
                if let testResult {
                    Text(testResult)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func detect() {
        if let url = environment.locateClaude(preferredPath: config.claudeAppPath) {
            detectionResult = "Found: \(url.path)"
        } else {
            detectionResult = "Claude was not found. Choose it manually."
        }
    }

    private func choose() {
        if let url = environment.presentClaudeChooser() {
            config.claudeAppPath = url.path
            detectionResult = "Selected: \(url.path)"
        }
    }

    private func runTest(dryRun: Bool) {
        // Push pending edits before testing so the run uses current settings.
        environment.updateConfiguration(config)
        Task {
            isTesting = true
            testResult = nil
            if dryRun {
                await environment.scheduler.runDryTest()
            } else {
                await environment.scheduler.sendTestMessage()
            }
            isTesting = false
            testResult = latestResultDescription()
        }
    }

    private func latestResultDescription() -> String {
        let entries = environment.scheduler.persistentState
        if let failure = entries.lastFailureDate,
           failure >= (entries.lastSuccessDate ?? .distantPast) {
            return "Last test failed at \(DateDisplay.timeString(failure)). See the Logs tab for details."
        }
        if let success = entries.lastSuccessDate {
            return "Last test succeeded at \(DateDisplay.timeString(success))."
        }
        return "Test completed. See the Logs tab for details."
    }
}

/// Edits a keyboard shortcut as a key character plus modifier toggles.
private struct ShortcutEditor: View {
    @Binding var shortcut: KeyboardShortcut

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Key")
                TextField("Key", text: keyBinding)
                    .frame(width: 44)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Shortcut key")
            }
            HStack {
                Toggle("⌘", isOn: $shortcut.command)
                Toggle("⇧", isOn: $shortcut.shift)
                Toggle("⌥", isOn: $shortcut.option)
                Toggle("⌃", isOn: $shortcut.control)
            }
            .toggleStyle(.button)
        }
    }

    private var keyBinding: Binding<String> {
        Binding(
            get: { shortcut.key },
            set: { newValue in
                // Keep a single lowercased character.
                shortcut.key = String(newValue.lowercased().prefix(1))
            }
        )
    }
}

/// A stepper for a sub-minute delay value, shown in seconds.
private struct DelayStepper: View {
    let title: String
    @Binding var seconds: TimeInterval

    var body: some View {
        Stepper(value: $seconds, in: 0...30, step: 0.5) {
            LabeledContent(title) {
                Text(String(format: "%.1f s", seconds))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("\(title): \(String(format: "%.1f", seconds)) seconds")
    }
}
