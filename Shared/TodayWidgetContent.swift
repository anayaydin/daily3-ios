import SwiftUI

struct TodayWidgetContent: View {
    let snapshot: TodayWidgetSnapshot
    var isCompact = false

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily 3")
                    .font(.headline)
                Spacer(minLength: 4)
                Text("\(snapshot.completedCount)/3")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(snapshot.completedCount == 3 ? .green : .secondary)
            }

            ForEach(snapshot.priorities) { priority in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: priority.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(priority.isCompleted ? .green : .secondary)
                    Text(priority.title.isEmpty ? "Priority \(priority.slot)" : priority.title)
                        .foregroundStyle(priority.title.isEmpty ? .secondary : .primary)
                        .strikethrough(priority.isCompleted)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(isCompact ? .caption : .subheadline)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(priority.title.isEmpty ? "Priority \(priority.slot), empty" : priority.title)
                .accessibilityValue(priority.isCompleted ? "Completed" : "Incomplete")
            }

            Spacer(minLength: 0)

            ProgressView(value: Double(snapshot.completedCount), total: 3)
                .progressViewStyle(WidgetProgressStyle())
                .accessibilityLabel("Today's progress")
                .accessibilityValue("\(snapshot.completedCount) of 3 completed")
        }
    }
}

private struct WidgetProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(.green)
                    .frame(width: geometry.size.width * (configuration.fractionCompleted ?? 0))
            }
        }
        .frame(height: 4)
    }
}
