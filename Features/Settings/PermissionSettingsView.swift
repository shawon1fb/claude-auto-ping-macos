import SwiftUI

/// Permissions checklist with concise explanations and a relevant action for
/// each item. Status is refreshed on appearance and after each action.
struct PermissionSettingsView: View {
    @Binding var config: SchedulerConfiguration
    let environment: AppEnvironment

    @State private var claudeFound = false
    @State private var accessibilityGranted = false
    @State private var launchAtLoginEnabled = false

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
                    title: "Automation permission available",
                    explanation: "Allows controlling System Events. Approve the prompt on first run.",
                    isSatisfied: nil,
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
                Text("Claude Auto Ping never prompts repeatedly. Use the buttons above to grant access in System Settings, then return here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Re-check permissions", action: refresh)
                Button("Request Accessibility prompt") {
                    environment.requestAccessibility()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        claudeFound = environment.locateClaude(preferredPath: config.claudeAppPath) != nil
        accessibilityGranted = environment.accessibilityGranted
        launchAtLoginEnabled = environment.isLaunchAtLoginEnabled
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
