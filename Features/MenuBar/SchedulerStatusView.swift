import SwiftUI

/// A compact status row showing the current scheduler state with an icon,
/// title, and supporting detail.
struct SchedulerStatusView: View {
    let status: SchedulerStatus

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: status.menuBarSymbolName)
                .foregroundStyle(status.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(.headline)
                Text(status.detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.title). \(status.detailText)")
    }
}
