import SwiftUI

struct WatchTodayView: View {
    let snapshot: TodayWidgetSnapshot
    let status: String
    var onToggle: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(snapshot.completedCount) of 3")
                    .font(.headline)
                    .monospacedDigit()
                Spacer()
                if snapshot.completedCount == 3 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Day complete")
                }
            }

            ForEach(snapshot.priorities) { priority in
                Button {
                    onToggle(priority.slot)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: priority.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(priority.isCompleted ? .green : .secondary)
                        Text(priority.title.isEmpty ? "Priority \(priority.slot)" : priority.title)
                            .foregroundStyle(priority.title.isEmpty ? .secondary : .primary)
                            .strikethrough(priority.isCompleted)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.body)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(priority.title.isEmpty)
                .accessibilityLabel(priority.title.isEmpty ? "Priority \(priority.slot), empty" : priority.title)
                .accessibilityValue(priority.isCompleted ? "Completed" : "Incomplete")
                .accessibilityHint(priority.title.isEmpty ? "" : "Toggle completion")
            }

            Text(status)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("watch.syncStatus")
        }
        .padding(.horizontal, 4)
    }
}
