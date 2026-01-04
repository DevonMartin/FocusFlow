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

    /// Scale factor for subtask estimates (blended / AI)
    /// Values < 1 mean user is faster, > 1 means slower
    var estimateScaleFactor: Double?

    // MARK: - Time Tracking

    /// Actual duration in seconds (set on completion)
    var actualDuration: TimeInterval?

    /// When the user started/resumed working on this task
    var startTime: Date?

    /// Accumulated duration from previous work sessions (seconds)
    /// Used to track time across pause/resume cycles
    var accumulatedDuration: TimeInterval?

    /// When the user finished working on this task
    var endTime: Date?

    // MARK: - Computed Time Properties

    /// Current elapsed work duration (accumulated + current session if running)
    var elapsedDuration: TimeInterval {
        let accumulated = accumulatedDuration ?? 0
        if let start = startTime {
            return accumulated + Date().timeIntervalSince(start)
        }
        return accumulated
    }

    /// Whether the task timer is currently running
    var isRunning: Bool {
        startTime != nil && !isComplete
    }

    /// Whether the task has been started but is currently paused
    var isPaused: Bool {
        startTime == nil && accumulatedDuration != nil && !isComplete
    }

    /// Whether the task has never been started
    var isNotStarted: Bool {
        startTime == nil && accumulatedDuration == nil && !isComplete
    }

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
        self.estimateScaleFactor = nil
        self.actualDuration = nil
        self.startTime = nil
        self.accumulatedDuration = nil
        self.endTime = nil
        self.isComplete = false
        self.createdAt = Date()
        self.completedAt = nil
        self.wasUsedForTraining = false
        self.subtasks = []
    }

    // MARK: - Timer Control

    /// Starts or resumes the task timer
    func start() {
        guard !isComplete else { return }
        if accumulatedDuration == nil {
            accumulatedDuration = 0
        }
        startTime = Date()
    }

    /// Pauses the task timer, preserving accumulated time
    func pause() {
        guard let start = startTime else { return }
        let sessionDuration = Date().timeIntervalSince(start)
        accumulatedDuration = (accumulatedDuration ?? 0) + sessionDuration
        startTime = nil
    }

    /// Completes the task, finalizing actual duration
    /// - Parameter duration: Override duration (for manual entry), or nil to use tracked time
    func complete(withDuration duration: TimeInterval? = nil) {
        if let override = duration {
            actualDuration = override
        } else if let start = startTime {
            // Currently running - add current session
            let sessionDuration = Date().timeIntervalSince(start)
            actualDuration = (accumulatedDuration ?? 0) + sessionDuration
        } else {
            // Paused or never started - use accumulated
            actualDuration = accumulatedDuration
        }

        endTime = Date()
        isComplete = true
        completedAt = Date()
        startTime = nil
    }
}
