import Charts
import SwiftData
import SwiftUI

struct StatisticsView: View {
    @Query(sort: \DailyEntry.date) private var entries: [DailyEntry]
    @State private var period: StatisticsPeriod = .week

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            statisticsContent(today: timeline.date)
        }
    }

    private func statisticsContent(today: Date) -> some View {
        let statistics = TaskStatistics(entries: entries, today: today)
        let activity = statistics.dailyActivity(for: period)

        return NavigationStack {
            List {
                Section("All Time") {
                    metricRow("Completed priorities", systemImage: "checkmark.circle", value: statistics.totalCompleted.formatted(), color: .green)
                        .accessibilityIdentifier("statistics.completed")
                    metricRow("3/3 days", systemImage: "calendar.badge.checkmark", value: statistics.completeDays.formatted(), color: .orange)
                    metricRow("Completion rate", systemImage: "chart.pie", value: statistics.completionRate?.formatted(.percent.precision(.fractionLength(0))) ?? "--", color: .blue)
                    Text("\(statistics.totalCompleted) of \(statistics.totalPlanned) planned priorities completed")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Daily Completions") {
                    Picker("Time range", selection: $period) {
                        ForEach(StatisticsPeriod.allCases) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("statistics.period")

                    if let first = activity.first, let last = activity.last {
                        Text("\(first.date.formatted(.dateTime.month(.abbreviated).day())) - \(last.date.formatted(.dateTime.month(.abbreviated).day().year()))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if activity.contains(where: { $0.filledCount > 0 }) {
                        activityChart(activity)
                    } else {
                        ContentUnavailableView(
                            "No priorities in this period",
                            systemImage: "chart.bar",
                            description: Text("Your daily priorities will appear here.")
                        )
                        .accessibilityIdentifier("statistics.empty")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Statistics")
        }
    }

    private func metricRow(_ title: String, systemImage: String, value: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
            }
            Spacer(minLength: 16)
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
                .layoutPriority(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private func activityChart(_ activity: [DailyStatistics]) -> some View {
        Chart(activity) { day in
            BarMark(
                x: .value("Day", day.date, unit: .day),
                y: .value("Completed", day.completedCount)
            )
            .foregroundStyle(.green)
            .cornerRadius(3)
            .accessibilityLabel(day.date.formatted(.dateTime.month(.wide).day().year()))
            .accessibilityValue("\(day.completedCount) of 3 completed")
        }
        .chartYScale(domain: 0...3)
        .chartYAxis {
            AxisMarks(values: [0, 1, 2, 3])
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 7)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day())
            }
        }
        .frame(height: 220)
        .padding(.vertical, 8)
        .accessibilityIdentifier("statistics.chart")
    }
}
