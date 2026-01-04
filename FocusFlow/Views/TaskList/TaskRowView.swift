//
//  TaskRowView.swift
//  FocusFlow
//
//  A single task row in the task list.
//

import SwiftUI

/// Content view for task rows, used inside NavigationLink or standalone
struct TaskRowContent: View {
    let task: TaskRecord
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Completion checkbox
            Button(action: onComplete) {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(
                        task.isComplete
                            ? DesignSystem.Colors.gentle
                            : DesignSystem.Colors.neutral
                    )
            }
            .buttonStyle(.plain)

            // Task content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.taskDescription)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(
                        task.isComplete
                            ? DesignSystem.Colors.textSecondary
                            : DesignSystem.Colors.text
                    )
                    .strikethrough(task.isComplete)
                    .lineLimit(2)

                // Subtitle with estimate, status, or category
                if let subtitle = subtitleText {
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(subtitleColor)
                }
            }

            Spacer()

            // Chevron for navigation (only for incomplete tasks)
            if !task.isComplete {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.neutral)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var subtitleText: String? {
        // Show running/paused status if applicable
        if task.isRunning {
            return "In progress"
        } else if task.isPaused {
            let minutes = Int(task.elapsedDuration / 60)
            return "Paused at \(DesignSystem.Language.formatDuration(minutes: minutes))"
        }

        // Completed tasks show actual duration
        if task.isComplete {
            if let actualDuration = task.actualDuration {
                return DesignSystem.Language.durationCompleted(seconds: actualDuration)
            }
            return nil
        }

        // Otherwise show estimate or category
        if let predictedDuration = task.predictedDuration {
            let minutes = Int(predictedDuration / 60)
            return DesignSystem.Language.timeEstimate(minutes)
        } else if let category = task.category {
            return category.rawValue.capitalized
        }
        return nil
    }

    private var subtitleColor: Color {
        if task.isRunning {
            return DesignSystem.Colors.primary
        } else if task.isPaused {
            return DesignSystem.Colors.secondary
        }
        return DesignSystem.Colors.textSecondary
    }
}

#if DEBUG
import SwiftData

#Preview("Task Rows") {
    let container = try! ModelContainer(
        for: TaskRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let incomplete = TaskRecord(taskDescription: "Clean the kitchen thoroughly")
    incomplete.predictedDuration = 1800
    incomplete.category = .cleaning

    let complete = TaskRecord(taskDescription: "Reply to emails")
    complete.isComplete = true
    complete.completedAt = Date()

    let simple = TaskRecord(taskDescription: "Quick task with no estimate yet")

    let inProgress = TaskRecord(taskDescription: "Working on something")
    inProgress.start()

    let paused = TaskRecord(taskDescription: "Paused task")
    paused.accumulatedDuration = 720 // 12 minutes

    return VStack(spacing: 8) {
        TaskRowContent(task: incomplete, onComplete: {})
        TaskRowContent(task: complete, onComplete: {})
        TaskRowContent(task: simple, onComplete: {})
        TaskRowContent(task: inProgress, onComplete: {})
        TaskRowContent(task: paused, onComplete: {})
    }
    .padding()
    .background(DesignSystem.Colors.background)
    .modelContainer(container)
}
#endif
