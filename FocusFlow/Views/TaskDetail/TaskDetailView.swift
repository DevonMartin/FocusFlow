//
//  TaskDetailView.swift
//  FocusFlow
//
//  Task detail screen with subtask list and timer controls.
//

import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Bindable var task: TaskRecord
    @Environment(\.dismiss) private var dismiss

    @State private var showingCompletionPrompt = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Subtask list
            if task.subtasks.isEmpty {
                emptyState
            } else {
                subtaskList
            }

            Spacer()

            // Timer controls at bottom
            timerControls
        }
        .background(DesignSystem.Colors.background)
        .navigationTitle(task.taskDescription)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            elapsedTime = task.elapsedDuration
            startTimerIfNeeded()
        }
        .onDisappear {
            timerTask?.cancel()
        }
        .sheet(isPresented: $showingCompletionPrompt) {
            CompletionPromptView(task: task) {
                dismiss()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "list.bullet")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.neutral)

            Text(DesignSystem.Language.noSubtasks)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Spacer()
        }
        .padding()
    }

    // MARK: - Subtask List

    private var subtaskList: some View {
        List {
            ForEach(sortedSubtasks) { subtask in
                SubtaskRowView(subtask: subtask)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var sortedSubtasks: [SubtaskRecord] {
        task.subtasks.sorted { $0.orderIndex < $1.orderIndex }
    }

    // MARK: - Timer Controls

    private var timerControls: some View {
        VStack(spacing: 16) {
            // Elapsed time display (only when started)
            if !task.isNotStarted {
                Text(formattedElapsedTime)
                    .font(DesignSystem.Typography.largeTitle)
                    .foregroundStyle(DesignSystem.Colors.text)
                    .monospacedDigit()
            }

            // Control buttons
            HStack(spacing: 16) {
                if task.isNotStarted {
                    GentleButton("Start", icon: "play.fill", style: .primary) {
                        startTask()
                    }
                } else if task.isRunning {
                    GentleButton("Pause", icon: "pause.fill", style: .secondary) {
                        pauseTask()
                    }
                    .frame(maxWidth: .infinity)

                    GentleButton("Done", icon: "checkmark", style: .primary) {
                        showingCompletionPrompt = true
                    }
                    .frame(maxWidth: .infinity)
                } else if task.isPaused {
                    GentleButton("Resume", icon: "play.fill", style: .primary) {
                        resumeTask()
                    }
                    .frame(maxWidth: .infinity)

                    GentleButton("Done", icon: "checkmark", style: .secondary) {
                        showingCompletionPrompt = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(DesignSystem.Colors.surface)
    }

    private var formattedElapsedTime: String {
        let totalSeconds = Int(elapsedTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    // MARK: - Timer Actions

    private func startTask() {
        task.start()
        startTimerIfNeeded()
    }

    private func pauseTask() {
        task.pause()
        timerTask?.cancel()
        elapsedTime = task.elapsedDuration
    }

    private func resumeTask() {
        task.start()
        startTimerIfNeeded()
    }

    private func startTimerIfNeeded() {
        guard task.isRunning else { return }

        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled {
                    elapsedTime = task.elapsedDuration
                }
            }
        }
    }
}

// MARK: - Subtask Row

struct SubtaskRowView: View {
    @Bindable var subtask: SubtaskRecord

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                withAnimation {
                    subtask.isComplete.toggle()
                }
            } label: {
                Image(systemName: subtask.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(
                        subtask.isComplete
                            ? DesignSystem.Colors.gentle
                            : DesignSystem.Colors.neutral
                    )
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(subtask.title)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(
                        subtask.isComplete
                            ? DesignSystem.Colors.textSecondary
                            : DesignSystem.Colors.text
                    )
                    .strikethrough(subtask.isComplete)

                Text(DesignSystem.Language.timeEstimate(subtask.scaledEstimateMinutes))
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#if DEBUG
import SwiftData

#Preview("Task Detail") {
    let container = try! ModelContainer(
        for: TaskRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let task = TaskRecord(taskDescription: "Clean the kitchen")
    task.predictedDuration = 1800
    task.category = .cleaning
    context.insert(task)

    let subtask1 = SubtaskRecord(title: "Gather cleaning supplies", estimatedMinutes: 5, difficulty: .easy, orderIndex: 0)
    let subtask2 = SubtaskRecord(title: "Clear and wipe counters", estimatedMinutes: 10, difficulty: .medium, orderIndex: 1)
    let subtask3 = SubtaskRecord(title: "Wash dishes", estimatedMinutes: 15, difficulty: .medium, orderIndex: 2)

    subtask1.task = task
    subtask2.task = task
    subtask3.task = task
    task.subtasks = [subtask1, subtask2, subtask3]

    return NavigationStack {
        TaskDetailView(task: task)
    }
    .modelContainer(container)
}

#Preview("Empty Subtasks") {
    let container = try! ModelContainer(
        for: TaskRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let task = TaskRecord(taskDescription: "Quick task without breakdown")
    context.insert(task)

    return NavigationStack {
        TaskDetailView(task: task)
    }
    .modelContainer(container)
}

#Preview("Task In Progress") {
    let container = try! ModelContainer(
        for: TaskRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let task = TaskRecord(taskDescription: "Working on something")
    task.start()
    context.insert(task)

    return NavigationStack {
        TaskDetailView(task: task)
    }
    .modelContainer(container)
}
#endif
