import SwiftUI

/// Permissions checklist with concise explanations and a relevant action for
/// each item. Status is refreshed on appearance, when the app becomes active,
/// while the tab is visible, and after each action — so a grant made in System
/// Settings is reflected without relaunching.
struct PermissionSettingsView: View {
    @Binding var config: SchedulerConfiguration
    let environment: AppEnvironment

    @State private var claudeFound = false
    @State private var accessibilityGranted = false
    @State private var automationStatus: PermissionStatus = .unknown
    @State private var launchAtLoginEnabled = false
    @State private var isProbingAutomation = false

    /// Lightweight poll so a live toggle in System Settings is picked up.
    private let pollTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                ChecklistRow(
                    title: "Claude app found",
                    explanation: "Claude must be installed so its window can be controlled.",
                    isSatisfied: claudeFound,
                    actionTitle: "Detect",
                    action: refresh
                )
                ChecklistRow(
                    title: "Accessibility permission granted",
                    explanation: "Required to send keystrokes that open a chat and paste the message.",
                    isSatisfied: accessibilityGranted,
                    actionTitle: "Open Settings",
                    action: { environment.openAccessibilitySettings() }
                )
                ChecklistRow(
                    title: "Automation permission",
                    explanation: automationExplanation,
                    isSatisfied: automationSatisfied,
                    actionTitle: "Open Settings",
                    action: { environment.openAutomationSettings() }
                )
                ChecklistRow(
                    title: "Launch at login",
                    explanation: "Optional. Starts Claude Auto Ping automatically when you log in.",
                    isSatisfied: launchAtLoginEnabled,
                    actionTitle: nil,
                    action: nil
                )
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Claude Auto Ping never prompts repeatedly. Use the buttons above to grant access in System Settings, then return here — the status updates automatically.")
                    Text("Automation can't be pre-granted: macOS only lists this app under Automation after it first tries to control another app. Run the dry-run below to trigger that one-time prompt, then approve System Events and Claude.")
                    Text("If you rebuilt an unsigned development build and the toggle looks on but stays red, remove the old \"ClaudeAutoPingMacos\" entry in Accessibility and add the current app again: its code signature changed.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    triggerAutomationPrompt()
                } label: {
                    HStack {
                        if isProbingAutomation { ProgressView().controlSize(.small) }
                        Text("Trigger Automation prompt (dry-run)")
                    }
                }
                .help("Runs a dry-run that asks macOS for Automation access, adding the app to the Automation list.")
                Button("Re-check permissions", action: refresh)
                Button("Request Accessibility prompt") {
                    environment.requestAccessibility()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
        .onReceive(pollTimer) { _ in
            refresh()
        }
    }

    private func refresh() {
        claudeFound = environment.locateClaude(preferredPath: config.claudeAppPath) != nil
        accessibilityGranted = environment.accessibilityGranted
        automationStatus = environment.automationStatus
        launchAtLoginEnabled = environment.isLaunchAtLoginEnabled
        // Keep the menu bar status in sync with the live permission state.
        environment.refreshPermissions()
    }

    private var automationSatisfied: Bool? {
        switch automationStatus {
        case .granted: return true
        case .denied: return false
        case .unknown: return nil
        }
    }

    private var automationExplanation: String {
        switch automationStatus {
        case .granted:
            return "Allows controlling System Events. Permission is granted."
        case .denied:
            return "Allows controlling System Events. Enable Claude Auto Ping in Automation settings."
        case .unknown:
            return "Allows controlling System Events. Approve the prompt on first run."
        }
    }

    private func triggerAutomationPrompt() {
        Task {
            isProbingAutomation = true
            // A dry-run performs the automation steps (which require Automation
            // access) without pressing Return, prompting macOS as a side effect.
            await environment.scheduler.runDryTest()
            isProbingAutomation = false
            refresh()
        }
    }
}

/// A single permission/status row with an optional action button.
private struct ChecklistRow: View {
    let title: String
    let explanation: String
    /// `nil` means the status cannot be reliably determined.
    let isSatisfied: Bool?
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            statusIcon
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                Text(explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .controlSize(.small)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(statusAccessibilityText). \(explanation)")
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch isSatisfied {
        case .some(true):
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .some(false):
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .none:
            Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
        }
    }

    private var statusAccessibilityText: String {
        switch isSatisfied {
        case .some(true): return "Satisfied"
        case .some(false): return "Not satisfied"
        case .none: return "Status unknown"
        }
    }
}
