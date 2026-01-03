//
//  TaskRecord.swift
//  FocusFlow
//
//  Main task entity with time tracking and AI-generated breakdown support.
//

import Foundation
import SwiftData

@Model
final class TaskRecord {
    @Attribute(.unique) var id: UUID
    var taskDescription: String

    // MARK: - AI-Generated Fields (nil until breakdown completes)

    /// Task category determined by Foundation Models
    var category: TaskCategory?

    /// Complexity rating 1-10 from AI analysis
    var complexity: Int?

    /// Number of steps from AI breakdown
    var stepCount: Int?

    /// Predicted duration in seconds from TimeEstimationService
    var predictedDuration: TimeInterval?

    // MARK: - Time Tracking

    /// Actual duration in seconds (set on completion)
    var actualDuration: TimeInterval?

    /// When the user started working on this task
    var startTime: Date?

    /// When the user finished working on this task
    var endTime: Date?

    // MARK: - Status

    var isComplete: Bool
    var createdAt: Date
    var completedAt: Date?

    // MARK: - ML Training

    /// Whether this task's data has been used for ML training
    var wasUsedForTraining: Bool

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade, inverse: \SubtaskRecord.task)
    var subtasks: [SubtaskRecord]

    // MARK: - Initialization

    init(taskDescription: String) {
        self.id = UUID()
        self.taskDescription = taskDescription
        self.category = nil
        self.complexity = nil
        self.stepCount = nil
        self.predictedDuration = nil
        self.actualDuration = nil
        self.startTime = nil
        self.endTime = nil
        self.isComplete = false
        self.createdAt = Date()
        self.completedAt = nil
        self.wasUsedForTraining = false
        self.subtasks = []
    }
}
