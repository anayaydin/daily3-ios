//
//  ContentView.swift
//  Daily3
//
//  Created by Ayse Nur AYAYDIN on 7.10.2026.
//

import SwiftUI

struct DailyTask: Identifiable, Equatable {
    let id: Int
    var title = ""
    var isCompleted = false

    var isFilled: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct TodayTasks {
    var tasks: [DailyTask] = (1...3).map { DailyTask(id: $0) }

    var completedCount: Int {
        tasks.filter { $0.isCompleted && $0.isFilled }.count
    }

    var filledCount: Int {
        tasks.filter(\.isFilled).count
    }

    var isDayComplete: Bool {
        completedCount == 3
    }
}

struct ContentView: View {
    @State private var todayTasks = TodayTasks()

    private var dateText: String {
        Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 28) {
                header

                VStack(spacing: 14) {
                    ForEach($todayTasks.tasks) { $task in
                        TaskRow(task: $task)
                    }
                }

                Spacer()

                progressSummary
            }
            .padding(24)
            .navigationTitle("Daily 3")
            .background(Color(.systemGroupedBackground))
        }
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
            ProgressView(value: Double(todayTasks.completedCount), total: 3)
                .accessibilityLabel("Daily progress")
                .accessibilityValue("\(todayTasks.completedCount) of 3 completed")

            HStack {
                Text("\(todayTasks.completedCount) of 3 completed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if todayTasks.isDayComplete {
                    Label("Day complete", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }
        }
    }
}

private struct TaskRow: View {
    @Binding var task: DailyTask

    var body: some View {
        HStack(spacing: 12) {
            Button {
                guard task.isFilled else { return }
                task.isCompleted.toggle()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Priority \(task.id) completion")
            .accessibilityValue(task.isCompleted ? "Completed" : "Incomplete")

            TextField("Priority \(task.id)", text: $task.title)
                .textFieldStyle(.plain)
                .font(.body)
                .submitLabel(.done)
                .accessibilityLabel("Priority \(task.id)")
                .onChange(of: task.title) { _, newValue in
                    if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        task.isCompleted = false
                    }
                }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
