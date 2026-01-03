//
//  EWMAEstimator.swift
//  FocusFlow
//
//  Exponential Weighted Moving Average estimator for personalized time predictions.
//  Gives more weight to recent task completions while smoothing out outliers.
//

import Foundation

struct EWMAEstimator {
    /// Weight for new data points (0-1). Higher = more reactive to recent data.
    private let alpha: Double

    /// Default estimate when no history exists (30 minutes in seconds)
    private let defaultEstimate: TimeInterval

    /// Current estimates per category
    private var categoryEstimates: [String: TimeInterval]

    /// Number of data points per category (for confidence calculation)
    private var categoryCounts: [String: Int]

    /// Storage for persistence
    private let storage: EWMAStorage

    init(
        alpha: Double = 0.3,
        defaultEstimate: TimeInterval = 1800,
        storage: EWMAStorage = UserDefaultsEWMAStorage()
    ) {
        self.alpha = alpha
        self.defaultEstimate = defaultEstimate
        self.storage = storage

        // Load persisted data
        let persisted = storage.load()
        self.categoryEstimates = persisted.estimates
        self.categoryCounts = persisted.counts
    }

    /// Returns the current estimate for a category
    func estimate(for category: String) -> TimeInterval {
        categoryEstimates[category] ?? defaultEstimate
    }

    /// Updates the estimate with a new actual duration and persists the change
    mutating func update(category: String, actualDuration: TimeInterval) {
        let currentEstimate = categoryEstimates[category] ?? defaultEstimate
        let newEstimate = alpha * actualDuration + (1 - alpha) * currentEstimate
        categoryEstimates[category] = newEstimate
        categoryCounts[category, default: 0] += 1

        // Persist after each update
        storage.save(estimates: categoryEstimates, counts: categoryCounts)
    }

    /// Returns how many data points exist for a category
    func dataPointCount(for category: String) -> Int {
        categoryCounts[category] ?? 0
    }

    /// Returns confidence level based on available data
    func confidenceLevel(for category: String) -> ConfidenceLevel {
        switch dataPointCount(for: category) {
        case 0..<5:
            return .low
        case 5..<20:
            return .medium
        default:
            return .high
        }
    }

    /// Clears all persisted data (useful for testing or reset)
    mutating func reset() {
        categoryEstimates = [:]
        categoryCounts = [:]
        storage.clear()
    }
}

// MARK: - Storage Protocol

protocol EWMAStorage: Sendable {
    func load() -> (estimates: [String: TimeInterval], counts: [String: Int])
    func save(estimates: [String: TimeInterval], counts: [String: Int])
    func clear()
}

// MARK: - UserDefaults Implementation

struct UserDefaultsEWMAStorage: EWMAStorage, Sendable {
    private let estimatesKey = "com.focusflow.ewma.estimates"
    private let countsKey = "com.focusflow.ewma.counts"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> (estimates: [String: TimeInterval], counts: [String: Int]) {
        let estimates = defaults.dictionary(forKey: estimatesKey) as? [String: TimeInterval] ?? [:]
        let counts = defaults.dictionary(forKey: countsKey) as? [String: Int] ?? [:]
        return (estimates, counts)
    }

    func save(estimates: [String: TimeInterval], counts: [String: Int]) {
        defaults.set(estimates, forKey: estimatesKey)
        defaults.set(counts, forKey: countsKey)
    }

    func clear() {
        defaults.removeObject(forKey: estimatesKey)
        defaults.removeObject(forKey: countsKey)
    }
}

// MARK: - In-Memory Implementation (for testing)

struct InMemoryEWMAStorage: EWMAStorage, Sendable {
    func load() -> (estimates: [String: TimeInterval], counts: [String: Int]) {
        ([:], [:])
    }

    func save(estimates: [String: TimeInterval], counts: [String: Int]) {
        // In-memory storage doesn't persist between instances
        // This is intentional for isolated test runs
    }

    func clear() {
        // No-op for in-memory
    }
}

// MARK: - Confidence Level

enum ConfidenceLevel: Equatable, Sendable {
    case low
    case medium
    case high

    var displayText: String {
        switch self {
        case .low:
            return "rough guess"
        case .medium:
            return "based on a few similar tasks"
        case .high:
            return "based on your history"
        }
    }
}
