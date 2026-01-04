//
//  TimeEstimationServiceTests.swift
//  FocusFlowTests
//

import Testing
@testable import FocusFlow

// MARK: - TimeEstimate Tests

@Suite("TimeEstimate")
@MainActor
struct TimeEstimateTests {

    @Test("minutes converts duration to minutes")
    func minutes_convertsDuration() {
        let estimate = TimeEstimate(duration: 1800, confidence: .medium, aiDuration: 1800)
        #expect(estimate.minutes == 30)
    }

    @Test("minutes truncates partial minutes")
    func minutes_truncatesPartial() {
        let estimate = TimeEstimate(duration: 1850, confidence: .low, aiDuration: 1800)
        #expect(estimate.minutes == 30)
    }

    @Test("scaleFactor is blended/AI ratio")
    func scaleFactor_isRatio() {
        // Blended is 1620, AI is 1800 -> scale = 0.9
        let estimate = TimeEstimate(duration: 1620, confidence: .low, aiDuration: 1800)
        #expect(estimate.scaleFactor == 0.9)
    }

    @Test("scaleFactor defaults to 1.0 when aiDuration is zero")
    func scaleFactor_defaultsToOne() {
        let estimate = TimeEstimate(duration: 1000, confidence: .low, aiDuration: 0)
        #expect(estimate.scaleFactor == 1.0)
    }
}

// MARK: - TimeEstimationService Tests

@Suite("TimeEstimationService")
@MainActor
struct TimeEstimationServiceTests {

    @Test("No history returns AI estimate with low confidence")
    func estimate_noHistory_returnsAIEstimate() {
        let estimator = EWMAEstimator(storage: InMemoryEWMAStorage())
        let service = TimeEstimationService(estimator: estimator)

        let result = service.estimate(aiEstimateMinutes: 30, category: .cleaning)

        #expect(result.duration == 1800)  // 30 minutes in seconds
        #expect(result.confidence == .low)
    }

    @Test("Low confidence blends 70% AI, 30% EWMA")
    func estimate_lowConfidence_blends70_30() {
        var estimator = EWMAEstimator(alpha: 1.0, storage: InMemoryEWMAStorage())
        // Add 2 data points (< 5 = low confidence)
        estimator.update(category: .work, actualDuration: 1200, baseEstimate: 1200)  // 20 min
        estimator.update(category: .work, actualDuration: 1200, baseEstimate: 1200)

        let service = TimeEstimationService(estimator: estimator)
        let result = service.estimate(aiEstimateMinutes: 30, category: .work)

        // AI: 30 min (1800s), EWMA: 20 min (1200s)
        // Blend: 0.7 * 1800 + 0.3 * 1200 = 1260 + 360 = 1620
        #expect(result.duration == 1620)
        #expect(result.confidence == .low)
    }

    @Test("Medium confidence blends 50% AI, 50% EWMA")
    func estimate_mediumConfidence_blends50_50() {
        var estimator = EWMAEstimator(alpha: 1.0, storage: InMemoryEWMAStorage())
        // Add 5 data points (5-19 = medium confidence)
        for _ in 0..<5 {
            estimator.update(category: .errands, actualDuration: 600, baseEstimate: 600)  // 10 min
        }

        let service = TimeEstimationService(estimator: estimator)
        let result = service.estimate(aiEstimateMinutes: 20, category: .errands)

        // AI: 20 min (1200s), EWMA: 10 min (600s)
        // Blend: 0.5 * 1200 + 0.5 * 600 = 600 + 300 = 900
        #expect(result.duration == 900)
        #expect(result.confidence == .medium)
    }

    @Test("High confidence blends 30% AI, 70% EWMA")
    func estimate_highConfidence_blends30_70() {
        var estimator = EWMAEstimator(alpha: 1.0, storage: InMemoryEWMAStorage())
        // Add 20 data points (>= 20 = high confidence)
        for _ in 0..<20 {
            estimator.update(category: .cooking, actualDuration: 2400, baseEstimate: 2400)  // 40 min
        }

        let service = TimeEstimationService(estimator: estimator)
        let result = service.estimate(aiEstimateMinutes: 20, category: .cooking)

        // AI: 20 min (1200s), EWMA: 40 min (2400s)
        // Blend: 0.3 * 1200 + 0.7 * 2400 = 360 + 1680 = 2040
        #expect(result.duration == 2040)
        #expect(result.confidence == .high)
    }

    @Test("Estimates from TaskBreakdown use totalMinutes and category")
    func estimate_fromBreakdown_usesTotalMinutesAndCategory() {
        let estimator = EWMAEstimator(storage: InMemoryEWMAStorage())
        let service = TimeEstimationService(estimator: estimator)

        let breakdown = TaskBreakdown(
            taskName: "Test",
            steps: [
                TaskStep(description: "Step 1", estimatedMinutes: 10, difficulty: .easy),
                TaskStep(description: "Step 2", estimatedMinutes: 20, difficulty: .medium)
            ],
            complexity: 3,
            category: .organizing
        )

        let result = service.estimate(for: breakdown)

        // totalMinutes = 30, no history = low confidence
        #expect(result.duration == 1800)
        #expect(result.confidence == .low)
    }

    @Test("recordCompletion updates EWMA for future estimates")
    func recordCompletion_updatesEWMA() {
        let estimator = EWMAEstimator(alpha: 1.0, storage: InMemoryEWMAStorage())
        var service = TimeEstimationService(estimator: estimator)

        // Record a completion: task took 20 min, was estimated at 30 min
        service.recordCompletion(
            actualDuration: 1200,  // 20 min
            category: .admin,
            originalEstimate: 1800  // 30 min
        )

        // Next estimate should blend with the recorded 20 min
        let result = service.estimate(aiEstimateMinutes: 30, category: .admin)

        // With alpha=1.0, EWMA = 1200 (fully weighted to actual)
        // Low confidence blend: 0.7 * 1800 + 0.3 * 1200 = 1260 + 360 = 1620
        #expect(result.duration == 1620)
    }
}
