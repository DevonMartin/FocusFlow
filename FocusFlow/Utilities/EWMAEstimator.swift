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

    /// Current estimates per category
    private var categoryEstimates: [TaskCategory: TimeInterval]

    /// Number of data points per category (for confidence calculation)
    private var categoryCounts: [TaskCategory: Int]

    /// Storage for persistence
    private let storage: EWMAStorage

    init(
        alpha: Double = 0.3,
        storage: EWMAStorage = UserDefaultsEWMAStorage()
    ) {
        self.alpha = alpha
        self.storage = storage

        // Load persisted data
        let persisted = storage.load()
        self.categoryEstimates = persisted.estimates
        self.categoryCounts = persisted.counts
    }

    /// Returns the current estimate for a category, or nil if no data exists
    func estimate(for category: TaskCategory) -> TimeInterval? {
        categoryEstimates[category]
    }

    /// Updates the estimate with a new actual duration and persists the change
    mutating func update(category: TaskCategory, actualDuration: TimeInterval, baseEstimate: TimeInterval) {
        let currentEstimate = categoryEstimates[category] ?? baseEstimate
        let newEstimate = alpha * actualDuration + (1 - alpha) * currentEstimate
        categoryEstimates[category] = newEstimate
        categoryCounts[category, default: 0] += 1

        // Persist after each update
        storage.save(estimates: categoryEstimates, counts: categoryCounts)
    }

    /// Returns total data points across all categories
    func totalDataPointCount() -> Int {
        categoryCounts.values.reduce(0, +)
    }

    /// Returns how many data points exist for a category
    func dataPointCount(for category: TaskCategory) -> Int {
        categoryCounts[category] ?? 0
    }

    /// Returns confidence level based on available data
    func confidenceLevel(for category: TaskCategory) -> ConfidenceLevel {
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
    func load() -> (estimates: [TaskCategory: TimeInterval], counts: [TaskCategory: Int])
    func save(estimates: [TaskCategory: TimeInterval], counts: [TaskCategory: Int])
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

    func load() -> (estimates: [TaskCategory: TimeInterval], counts: [TaskCategory: Int]) {
        var estimates: [TaskCategory: TimeInterval] = [:]
        var counts: [TaskCategory: Int] = [:]

        if let rawEstimates = defaults.dictionary(forKey: estimatesKey) as? [String: TimeInterval] {
            for (key, value) in rawEstimates {
                if let category = TaskCategory(rawValue: key) {
                    estimates[category] = value
                }
            }
        }

        if let rawCounts = defaults.dictionary(forKey: countsKey) as? [String: Int] {
            for (key, value) in rawCounts {
                if let category = TaskCategory(rawValue: key) {
                    counts[category] = value
                }
            }
        }

        return (estimates, counts)
    }

    func save(estimates: [TaskCategory: TimeInterval], counts: [TaskCategory: Int]) {
        let rawEstimates = Dictionary(uniqueKeysWithValues: estimates.map { ($0.key.rawValue, $0.value) })
        let rawCounts = Dictionary(uniqueKeysWithValues: counts.map { ($0.key.rawValue, $0.value) })

        defaults.set(rawEstimates, forKey: estimatesKey)
        defaults.set(rawCounts, forKey: countsKey)
    }

    func clear() {
        defaults.removeObject(forKey: estimatesKey)
        defaults.removeObject(forKey: countsKey)
    }
}

// MARK: - In-Memory Implementation (for testing)

struct InMemoryEWMAStorage: EWMAStorage, Sendable {
    func load() -> (estimates: [TaskCategory: TimeInterval], counts: [TaskCategory: Int]) {
        ([:], [:])
    }

    func save(estimates: [TaskCategory: TimeInterval], counts: [TaskCategory: Int]) {
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
