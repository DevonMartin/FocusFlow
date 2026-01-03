//
//  TaskRowView.swift
//  FocusFlow
//
//  A single task row in the task list.
//

import SwiftUI

struct TaskRowView: View {
    let task: TaskRecord
    let onTap: () -> Void
    let onComplete: () -> Void

    var body: some View {
        Button(action: onTap) {
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

                    // Subtitle with estimate or category
                    if let subtitle = subtitleText {
                        Text(subtitle)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()

                // Chevron for navigation
                if !task.isComplete {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.neutral)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var subtitleText: String? {
        if let predictedDuration = task.predictedDuration {
            let minutes = Int(predictedDuration / 60)
            return DesignSystem.Language.timeEstimate(minutes)
        } else if let category = task.category {
            return category.rawValue.capitalized
        }
        return nil
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

    return VStack(spacing: 8) {
        TaskRowView(task: incomplete, onTap: {}, onComplete: {})
        TaskRowView(task: complete, onTap: {}, onComplete: {})
        TaskRowView(task: simple, onTap: {}, onComplete: {})
    }
    .padding()
    .background(DesignSystem.Colors.background)
    .modelContainer(container)
}
#endif
