import SwiftUI

struct SessionsInfoRow: View {
    let stats: AggregatedStats

    var body: some View {
        HStack {
            InfoItem(icon: "bolt.fill", label: "Sessions", value: "\(stats.sessionCount)")
            Spacer()
            InfoItem(icon: "folder.fill", label: "Projects", value: "\(stats.projectCount)")
            Spacer()
            InfoItem(icon: "clock", label: "Active", value: formatDuration(stats.activeDuration))
        }
        .padding(.horizontal, DS.spacing12)
        .padding(.vertical, DS.spacing8)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "<1m"
    }
}

struct InfoItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: DS.spacing4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.textFaint)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.textFaint)
                Text(value)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundColor(.textSecondary)
            }
        }
    }
}
