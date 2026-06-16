import SwiftUI

/// The menu bar popover. Shows status, schedule summary, and the primary
/// actions, following the layout described in the project plan.
struct MenuBarView: View {
    @Environment(\.openSettings) private var openSettings
    @State private var viewModel: MenuBarViewModel
    @State private var isSending = false

    init(environment: AppEnvironment) {
        _viewModel = State(initialValue: MenuBarViewModel(environment: environment))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppInfo.displayName)
                .font(.headline)

            SchedulerStatusView(status: viewModel.status)

            Divider()

            summary

            Divider()

            resetControl

            Divider()

            actions

            Text("Recent result")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(viewModel.lastResultText)
                .font(.callout)

            Divider()

            footer
        }
        .padding(14)
        .frame(width: 300)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledRow(label: "Next message", value: viewModel.nextRunText)
            LabeledRow(label: "Interval", value: viewModel.intervalText)
            LabeledRow(label: "Message", value: viewModel.messagePreview)
        }
    }

    private var resetControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: anchorBinding) {
                Text("Send at Claude's reset time")
                    .font(.callout)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("Schedule each message at your Claude 5-hour reset time.")

            if viewModel.anchorToResetTime {
                HStack {
                    Text("Reset time")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    DatePicker("", selection: resetBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.stepperField)
                        .accessibilityLabel("Claude reset time")
                }
                if !viewModel.hasResetTime {
                    Text("Pick the time your limit resets to anchor the schedule.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var anchorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.anchorToResetTime },
            set: { viewModel.setAnchorToResetTime($0) }
        )
    }

    private var resetBinding: Binding<Date> {
        Binding(
            get: { viewModel.resetTime },
            set: { viewModel.setResetTime($0) }
        )
    }

    @ViewBuilder
    private var actions: some View {
        Button {
            Task {
                isSending = true
                await viewModel.sendTest()
                isSending = false
            }
        } label: {
            HStack {
                if isSending { ProgressView().controlSize(.small) }
                Text(isSending ? "Sending…" : "Send Test Message")
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(isSending)
        .help("Send the configured message now as a one-off test.")

        schedulerControl
    }

    @ViewBuilder
    private var schedulerControl: some View {
        if viewModel.isStopped {
            Button("Start Scheduler") { viewModel.start() }
                .frame(maxWidth: .infinity)
                .help("Begin sending the message on the configured interval.")
        } else if viewModel.canPause {
            Button("Pause Scheduler") { viewModel.pause() }
                .frame(maxWidth: .infinity)
                .help("Temporarily stop scheduled sends.")
        } else {
            Button("Resume Scheduler") { viewModel.resume() }
                .frame(maxWidth: .infinity)
                .help("Resume scheduled sends.")
        }
    }

    private var footer: some View {
        HStack {
            Button("Settings…") { showSettings() }
                .help("Open settings.")
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .help("Quit Claude Auto Ping.")
        }
    }

    /// Opens the Settings window and brings it to the front. As a menu-bar
    /// (`.accessory`) app we don't auto-activate, so a freshly opened Settings
    /// window appears behind other apps unless we activate and order it front.
    private func showSettings() {
        openSettings()
        // The window isn't in `NSApp.windows` until the next runloop tick.
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let settingsWindow = NSApp.windows.first { window in
                window.identifier?.rawValue.contains("Settings") == true
            }
            settingsWindow?.makeKeyAndOrderFront(nil)
        }
    }
}

/// A label/value row used in the popover summary.
private struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
