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

            Section("Claude reset window") {
                Toggle("Send at Claude's reset time", isOn: $config.anchorToResetTime)
                if config.anchorToResetTime {
                    DatePicker(
                        "Reset time",
                        selection: resetTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    if config.resetAnchorDate == nil {
                        Text("Set the time your Claude 5-hour usage limit resets. Until then, the schedule uses now + interval.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Text("The next message is sent at this time, then every interval after — so each send lands at a 5-hour window reset.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    /// Binds the optional reset anchor to a non-optional `DatePicker`, defaulting
    /// to the next top of the hour when unset.
    private var resetTimeBinding: Binding<Date> {
        Binding(
            get: { config.resetAnchorDate ?? Self.defaultResetTime() },
            set: { config.resetAnchorDate = $0 }
        )
    }

    private static func defaultResetTime() -> Date {
        let calendar = Calendar.current
        let nextHour = calendar.nextDate(
            after: Date(),
            matching: DateComponents(minute: 0),
            matchingPolicy: .nextTime
        )
        return nextHour ?? Date()
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
