import SwiftUI

/// Displays recent execution logs with copy, export, and clear actions. Logs
/// never include the configured message content — only privacy-safe metadata.
struct LogsView: View {
    @State private var viewModel: LogsViewModel
    @State private var selection: LogEntry.ID?

    init(environment: AppEnvironment) {
        _viewModel = State(initialValue: LogsViewModel(logStore: environment.logStore))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.entries.isEmpty {
                ContentUnavailableView(
                    "No logs yet",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Execution results will appear here.")
                )
                .frame(maxHeight: .infinity)
            } else {
                List(selection: $selection) {
                    ForEach(viewModel.entries) { entry in
                        LogRow(entry: entry)
                            .tag(entry.id)
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            toolbar
        }
        .task { await viewModel.refresh() }
    }

    private var toolbar: some View {
        HStack {
            Button("Refresh") { Task { await viewModel.refresh() } }
            Button("Copy selected") { copySelected() }
                .disabled(selection == nil)
            Spacer()
            Button("Clear", role: .destructive) { Task { await viewModel.clear() } }
                .disabled(viewModel.entries.isEmpty)
        }
        .padding(8)
    }

    private func copySelected() {
        guard let id = selection,
              let entry = viewModel.entries.first(where: { $0.id == id }) else { return }
        let text = LogFormatting.plainText(entry)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

/// A single log row summarizing one execution.
private struct LogRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .foregroundStyle(entry.success ? .green : .red)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(DateDisplay.dateTimeString(entry.timestamp))
                        .font(.callout)
                    Text(entry.trigger.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let error = entry.errorDescription {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("\(entry.messageCharacterCount) chars • \(String(format: "%.1fs", entry.duration))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(LogFormatting.accessibilityLabel(entry))
    }
}

/// Formats log entries into plain text for copying and accessibility.
enum LogFormatting {
    static func plainText(_ entry: LogEntry) -> String {
        var lines: [String] = []
        lines.append("Timestamp: \(DateDisplay.dateTimeString(entry.timestamp))")
        lines.append("Trigger: \(entry.trigger.displayName)")
        lines.append("Success: \(entry.success)")
        lines.append("Launched Claude: \(entry.didLaunchClaude)")
        lines.append("Opened new chat: \(entry.didOpenNewChat)")
        lines.append("Pasted: \(entry.didPaste)")
        lines.append("Sent: \(entry.didSend)")
        lines.append("Message characters: \(entry.messageCharacterCount)")
        if let hash = entry.messageHashPrefix {
            lines.append("Message hash: \(hash)")
        }
        lines.append("Duration: \(String(format: "%.2fs", entry.duration))")
        if let error = entry.errorDescription {
            lines.append("Error: \(error)")
        }
        return lines.joined(separator: "\n")
    }

    static func accessibilityLabel(_ entry: LogEntry) -> String {
        let outcome = entry.success ? "Succeeded" : "Failed"
        let when = DateDisplay.dateTimeString(entry.timestamp)
        let detail = entry.errorDescription ?? "\(entry.messageCharacterCount) characters"
        return "\(outcome) at \(when) via \(entry.trigger.displayName). \(detail)."
    }
}
