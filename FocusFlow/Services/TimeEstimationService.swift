//
//  TimeEstimationService.swift
//  FocusFlow
//
//  Blends AI-generated time estimates with EWMA-adjusted predictions
//  based on user's historical task completion data.
//

import Foundation

/// Result of a time estimation with duration and confidence
struct TimeEstimate: Equatable, Sendable {
    /// Estimated duration in seconds
    let duration: TimeInterval

    /// Confidence level based on available historical data
    let confidence: ConfidenceLevel

    /// Estimated duration in minutes (convenience accessor)
    var minutes: Int {
        Int(duration / 60)
    }
}

/// Pure service for estimating task durations.
/// Combines AI estimates with EWMA-adjusted historical data.
struct TimeEstimationService {
	private var estimator: EWMAEstimator

    /// Creates a service with an injected estimator (for testing)
    init(estimator: EWMAEstimator) {
        self.estimator = estimator
    }

    /// Records actual task duration to improve future estimates
    /// - Parameters:
    ///   - actualDuration: How long the task actually took (seconds)
    ///   - category: The task category
    ///   - originalEstimate: The original AI estimate (seconds)
    mutating func recordCompletion(
        actualDuration: TimeInterval,
        category: TaskCategory,
        originalEstimate: TimeInterval
    ) {
        estimator.update(
            category: category,
            actualDuration: actualDuration,
            baseEstimate: originalEstimate
        )
    }

    /// Estimates duration for a task based on AI estimate and historical data
    /// - Parameters:
    ///   - aiEstimateMinutes: The AI-generated estimate in minutes
    ///   - category: The task category for EWMA lookup
    /// - Returns: A TimeEstimate with adjusted duration and confidence
    func estimate(aiEstimateMinutes: Int, category: TaskCategory) -> TimeEstimate {
        let aiDuration = TimeInterval(aiEstimateMinutes * 60)
        let confidence = estimator.confidenceLevel(for: category)

        // If we have historical data, blend AI estimate with EWMA
        guard let ewmaEstimate = estimator.estimate(for: category) else {
            // No history - use AI estimate directly with low confidence
            return TimeEstimate(duration: aiDuration, confidence: .low)
        }

        // Blend based on confidence level
        let blendedDuration: TimeInterval
        switch confidence {
        case .low:
            // Few data points - weight AI more heavily (70/30)
            blendedDuration = 0.7 * aiDuration + 0.3 * ewmaEstimate
        case .medium:
            // Moderate data - equal weight (50/50)
            blendedDuration = 0.5 * aiDuration + 0.5 * ewmaEstimate
        case .high:
            // Strong history - trust EWMA more (30/70)
            blendedDuration = 0.3 * aiDuration + 0.7 * ewmaEstimate
        }

        return TimeEstimate(duration: blendedDuration, confidence: confidence)
    }

    /// Estimates total duration for a task breakdown
    /// - Parameter breakdown: The task breakdown with steps and category
    /// - Returns: A TimeEstimate for the entire task
    func estimate(for breakdown: TaskBreakdown) -> TimeEstimate {
        estimate(aiEstimateMinutes: breakdown.totalMinutes, category: breakdown.category)
    }
}
