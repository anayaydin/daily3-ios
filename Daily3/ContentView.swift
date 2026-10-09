//
//  ContentView.swift
//  Daily3
//
//  Created by Ayse Nur AYAYDIN on 7.10.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyEntry.date) private var entries: [DailyEntry]

    private var todayStart: Date {
        Calendar.current.startOfDay(for: .now)
    }

    private var todayEntry: DailyEntry? {
        entries.first { Calendar.current.isDate($0.date, inSameDayAs: todayStart) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let todayEntry {
                    TodayEntryView(entry: todayEntry)
                } else {
                    ProgressView("Preparing today")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Daily 3")
            .background(Color(.systemGroupedBackground))
            .onAppear(perform: createTodayEntryIfNeeded)
        }
    }

    private func createTodayEntryIfNeeded() {
        guard todayEntry == nil else { return }

        modelContext.insert(DailyEntry(date: todayStart))
        try? modelContext.save()
    }
}

private struct TodayEntryView: View {
    @Bindable var entry: DailyEntry

    private var dateText: String {
        entry.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            header

            VStack(spacing: 14) {
                ForEach(entry.sortedTasks, id: \.slot) { task in
                    TaskRow(task: task)
                }
            }

            Spacer()

            progressSummary
        }
        .padding(24)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dateText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Choose three priorities for today.")
                .font(.title2)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)

            Text("Keep the list small, clear, and finishable.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var progressSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProgressView(value: Double(entry.completedCount), total: 3)
                .accessibilityLabel("Daily progress")
                .accessibilityValue("\(entry.completedCount) of 3 completed")

            HStack {
                Text("\(entry.completedCount) of 3 completed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if entry.isDayComplete {
                    Label("Day complete", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }
        }
    }
}

private struct TaskRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: DailyTaskItem

    var body: some View {
        HStack(spacing: 12) {
            Button {
                guard task.isFilled else { return }
                task.isCompleted.toggle()
                saveChanges()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Priority \(task.slot) completion")
            .accessibilityValue(task.isCompleted ? "Completed" : "Incomplete")

            TextField("Priority \(task.slot)", text: $task.title)
                .textFieldStyle(.plain)
                .font(.body)
                .submitLabel(.done)
                .accessibilityLabel("Priority \(task.slot)")
                .onChange(of: task.title) { _, newValue in
                    if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        task.isCompleted = false
                    }
                    saveChanges()
                }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func saveChanges() {
        try? modelContext.save()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .modelContainer(for: [DailyEntry.self, DailyTaskItem.self], inMemory: true)
    }
}
