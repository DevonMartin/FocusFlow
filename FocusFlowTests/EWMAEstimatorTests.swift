//
//  EWMAEstimatorTests.swift
//  FocusFlowTests
//
//  Unit tests for EWMAEstimator.
//

import Testing
@testable import FocusFlow
import Foundation

@Suite("EWMAEstimator")
struct EWMAEstimatorTests {

    @Test("Returns default estimate with no history")
    func estimate_withNoHistory_returnsDefault() {
        let estimator = EWMAEstimator(storage: InMemoryEWMAStorage())
        let estimate = estimator.estimate(for: "cleaning")

        #expect(estimate == 1800) // 30 min default
    }

    @Test("Returns custom default estimate when configured")
    func estimate_withCustomDefault_returnsCustomDefault() {
        let estimator = EWMAEstimator(defaultEstimate: 900, storage: InMemoryEWMAStorage())
        let estimate = estimator.estimate(for: "cleaning")

        #expect(estimate == 900) // 15 min custom default
    }

    @Test("Blends estimate correctly after single update")
    func estimate_afterSingleUpdate_blendsProperly() {
        var estimator = EWMAEstimator(storage: InMemoryEWMAStorage()) // alpha = 0.3
        estimator.update(category: "cleaning", actualDuration: 3600) // 60 min actual

        let estimate = estimator.estimate(for: "cleaning")
        // With alpha=0.3: 0.3 * 3600 + 0.7 * 1800 = 1080 + 1260 = 2340
        #expect(abs(estimate - 2340) < 0.1)
    }

    @Test("Converges toward actual after multiple consistent updates")
    func estimate_afterMultipleUpdates_converges() {
        var estimator = EWMAEstimator(storage: InMemoryEWMAStorage())
        let actualDuration: TimeInterval = 2400 // 40 min

        for _ in 0..<20 {
            estimator.update(category: "cleaning", actualDuration: actualDuration)
        }

        let estimate = estimator.estimate(for: "cleaning")
        // Should converge close to 2400
        #expect(abs(estimate - actualDuration) < 10)
    }

    @Test("Maintains separate estimates per category")
    func estimate_perCategory_maintainsSeparateEstimates() {
        var estimator = EWMAEstimator(storage: InMemoryEWMAStorage())

        estimator.update(category: "cleaning", actualDuration: 3600)
        estimator.update(category: "cooking", actualDuration: 1200)

        let cleaningEstimate = estimator.estimate(for: "cleaning")
        let cookingEstimate = estimator.estimate(for: "cooking")

        #expect(cleaningEstimate != cookingEstimate)
        #expect(cleaningEstimate > cookingEstimate)
    }

    @Test("Higher alpha reacts faster to new data")
    func estimate_withHigherAlpha_reactsFaster() {
        var slowEstimator = EWMAEstimator(alpha: 0.1, storage: InMemoryEWMAStorage())
        var fastEstimator = EWMAEstimator(alpha: 0.5, storage: InMemoryEWMAStorage())

        slowEstimator.update(category: "test", actualDuration: 3600)
        fastEstimator.update(category: "test", actualDuration: 3600)

        let slowEstimate = slowEstimator.estimate(for: "test")
        let fastEstimate = fastEstimator.estimate(for: "test")

        // Fast estimator should be closer to 3600
        #expect(fastEstimate > slowEstimate)
    }

    @Test("Tracks data point count correctly")
    func dataPointCount_incrementsWithUpdates() {
        var estimator = EWMAEstimator(storage: InMemoryEWMAStorage())

        #expect(estimator.dataPointCount(for: "cleaning") == 0)

        estimator.update(category: "cleaning", actualDuration: 1800)
        #expect(estimator.dataPointCount(for: "cleaning") == 1)

        estimator.update(category: "cleaning", actualDuration: 1800)
        #expect(estimator.dataPointCount(for: "cleaning") == 2)
    }
}

@Suite("EWMAEstimator Persistence")
struct EWMAEstimatorPersistenceTests {

    @Test("Persists estimates to UserDefaults")
    func persistence_savesAndLoads() {
        let testDefaults = UserDefaults(suiteName: "TestEWMA")!
        testDefaults.removePersistentDomain(forName: "TestEWMA")

        let storage = UserDefaultsEWMAStorage(defaults: testDefaults)

        // Create estimator and add data
        var estimator1 = EWMAEstimator(storage: storage)
        estimator1.update(category: "cleaning", actualDuration: 3600)
        estimator1.update(category: "cleaning", actualDuration: 3600)

        let estimate1 = estimator1.estimate(for: "cleaning")
        let count1 = estimator1.dataPointCount(for: "cleaning")

        // Create new estimator with same storage — should load persisted data
        let estimator2 = EWMAEstimator(storage: storage)

        #expect(estimator2.estimate(for: "cleaning") == estimate1)
        #expect(estimator2.dataPointCount(for: "cleaning") == count1)

        // Cleanup
        testDefaults.removePersistentDomain(forName: "TestEWMA")
    }

    @Test("Reset clears persisted data")
    func reset_clearsPersistence() {
        let testDefaults = UserDefaults(suiteName: "TestEWMAReset")!
        testDefaults.removePersistentDomain(forName: "TestEWMAReset")

        let storage = UserDefaultsEWMAStorage(defaults: testDefaults)

        var estimator = EWMAEstimator(storage: storage)
        estimator.update(category: "cleaning", actualDuration: 3600)
        estimator.reset()

        // New estimator should have no data
        let freshEstimator = EWMAEstimator(storage: storage)
        #expect(freshEstimator.dataPointCount(for: "cleaning") == 0)
        #expect(freshEstimator.estimate(for: "cleaning") == 1800) // Default

        // Cleanup
        testDefaults.removePersistentDomain(forName: "TestEWMAReset")
    }
}

@Suite("ConfidenceLevel")
@MainActor
struct ConfidenceLevelTests {

    @Test("Low confidence with fewer than 5 data points")
    func confidenceLevel_lessThan5_returnsLow() {
        var estimator = EWMAEstimator(storage: InMemoryEWMAStorage())

        #expect(estimator.confidenceLevel(for: "cleaning") == .low)

        for _ in 0..<4 {
            estimator.update(category: "cleaning", actualDuration: 1800)
        }
        #expect(estimator.confidenceLevel(for: "cleaning") == .low)
    }

    @Test("Medium confidence with 5-19 data points")
    func confidenceLevel_5to19_returnsMedium() {
        var estimator = EWMAEstimator(storage: InMemoryEWMAStorage())

        for _ in 0..<5 {
            estimator.update(category: "cleaning", actualDuration: 1800)
        }
        #expect(estimator.confidenceLevel(for: "cleaning") == .medium)

        for _ in 0..<14 {
            estimator.update(category: "cleaning", actualDuration: 1800)
        }
        #expect(estimator.confidenceLevel(for: "cleaning") == .medium)
    }

    @Test("High confidence with 20+ data points")
    func confidenceLevel_20plus_returnsHigh() {
        var estimator = EWMAEstimator(storage: InMemoryEWMAStorage())

        for _ in 0..<20 {
            estimator.update(category: "cleaning", actualDuration: 1800)
        }
        #expect(estimator.confidenceLevel(for: "cleaning") == .high)
    }

    @Test("Display text returns user-friendly strings")
    func displayText_returnsUserFriendlyStrings() {
        #expect(ConfidenceLevel.low.displayText == "rough guess")
        #expect(ConfidenceLevel.medium.displayText == "based on a few similar tasks")
        #expect(ConfidenceLevel.high.displayText == "based on your history")
    }
}
