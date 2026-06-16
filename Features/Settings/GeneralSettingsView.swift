import SwiftUI

/// General settings: the message, interval, and high-level behavior toggles.
struct GeneralSettingsView: View {
    @Binding var config: SchedulerConfiguration
    let environment: AppEnvironment

    @State private var launchAtLogin: Bool = false

    var body: some View {
        Form {
            Section("Message") {
                TextField("Message", text: $config.message, axis: .vertical)
                    .lineLimit(1...4)
                    .accessibilityLabel("Message to send")
                Text("This exact text is sent to a new Claude chat. Unicode and Bangla are supported.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Schedule") {
                Picker("Interval", selection: $config.intervalPreset) {
                    ForEach(IntervalPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }

                if config.intervalPreset == .custom {
                    CustomIntervalEditor(seconds: $config.customIntervalSeconds)
                }

                if config.isShortInterval {
                    Label(
                        "Short intervals send frequently and may be disruptive.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }

            Section("Behavior") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        environment.setLaunchAtLogin(newValue)
                    }
                Toggle("Start scheduler automatically after launch", isOn: $config.startAutomatically)
                Toggle("Run once after waking when overdue", isOn: $config.wakeRecoveryEnabled)
                Toggle("Show notification after successful send", isOn: $config.notifyOnSuccess)
                Toggle("Show notification after failure", isOn: $config.notifyOnFailure)
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin = environment.isLaunchAtLoginEnabled }
    }
}

/// Edits a custom interval as separate hour and minute steppers, clamped to the
/// supported minimum.
private struct CustomIntervalEditor: View {
    @Binding var seconds: TimeInterval

    private var hours: Int { Int(seconds) / 3600 }
    private var minutes: Int { (Int(seconds) % 3600) / 60 }

    var body: some View {
        HStack {
            Stepper(value: hoursBinding, in: 0...48) {
                Text("\(hours) h")
            }
            Stepper(value: minutesBinding, in: 0...59, step: 5) {
                Text("\(minutes) m")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var hoursBinding: Binding<Int> {
        Binding(
            get: { hours },
            set: { newHours in update(hours: newHours, minutes: minutes) }
        )
    }

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { minutes },
            set: { newMinutes in update(hours: hours, minutes: newMinutes) }
        )
    }

    private func update(hours: Int, minutes: Int) {
        let total = TimeInterval(hours * 3600 + minutes * 60)
        seconds = max(total, SchedulerConfiguration.minimumIntervalSeconds)
    }
}
