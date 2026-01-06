# FocusFlow Time Estimation — Migration Plan

## Overview

This document maps the specific changes needed to migrate from the current single-dimension EWMA system to the multi-dimensional Bayesian estimation system.

**Current state:** Single FM call returns breakdown + estimates. EWMA tracks absolute duration by category only. Blends AI estimate with EWMA.

**Target state:** Three FM calls (breakdown, classification, per-step estimation). Bayesian system tracks ratio (actual/baseline) across engagement × duration × category × complexity. User confirms classification via streamlined "Look Good?" flow.

---

## Design Principles

### Latency Mitigation — Pipelined FM Calls

The three FM calls are pipelined to overlap with user actions, minimizing perceived latency:

```
User enters task description
         │
         ▼
┌─────────────────────────────────────────────────────┐
│  FM Call 1: generateBreakdown()                     │
│  (creative, temp > 0)                               │
└─────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│  USER EDITS SUBTASKS                                │
│  (reorder, add, edit, delete, add context)          │
│                                                     │
│  MEANWHILE IN BACKGROUND:                           │
│  FM Call 2: classifyTask() starts immediately       │
│  (deterministic, temp = 0)                          │
└─────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│  "LOOK GOOD?" CONFIRMATION SCREEN                   │
│                                                     │
│  Shows: Category, Engagement, Complexity            │
│  Time estimate range (once ready)                   │
│                                                     │
│  ┌─────────────────────────────────────────────┐   │
│  │  ✓ Yes, let's go                            │   │
│  └─────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────┐   │
│  │  Change classification                       │   │
│  └─────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────┐   │
│  │  Edit steps                                  │   │
│  └─────────────────────────────────────────────┘   │
│                                                     │
│  MEANWHILE IN BACKGROUND:                           │
│  FM Call 3: estimateAllSteps() starts               │
│  (deterministic, temp = 0)                          │
└─────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│  TASK CREATED                                       │
│  (estimate already computed, no wait)               │
└─────────────────────────────────────────────────────┘
```

**Perceived latency = just the initial breakdown.** Classification runs while user edits. Estimation runs while user confirms. By the time they tap "Yes, let's go," everything's ready.

**Edge cases:**
- User taps confirm before estimation finishes → brief "Calculating time..." spinner (should be rare)
- User goes back to edit steps after confirming → re-run estimation on changed steps

### No Per-Subtask Time Display

Per-subtask times are removed from the UI entirely:

1. **Scaling was conceptually awkward** — "AI said 10 min, you're 1.3x slower, so 13 min" applies a category-level ratio to a guess
2. **Creates false precision** — Seven steps with times invites mental addition and comparison to the total (different calculation path)
3. **ADHD context** — Per-step times may induce time anxiety rather than focus on the next action

**Instead:**
- `SubtaskRecord` keeps `baselineMinutes` (needed for total calculation)
- UI shows subtask title + difficulty indicator (easy/medium/hard), no time
- Total adjusted time shown once, at the task level, as a **range**

### Range-Based Time Display

Research shows precise estimates lose trust. Always display ranges:

```swift
// Instead of: "~43 min"
// Display: "35–50 min" or "This might take you 35–50 minutes"
```

Range width varies by confidence:
- **Very Low (0-2 obs):** ±35% → "28–58 min" for 43
- **Low (3-5 obs):** ±25% → "32–54 min"
- **Medium (6-11 obs):** ±20% → "34–52 min"
- **Good (12-19 obs):** ±15% → "37–49 min"
- **High (20+ obs):** ±10% → "39–47 min"

Wide ranges early set honest expectations. Narrow ranges over time build trust.

### Deferred: Time Decay

Old observations currently count equally with new ones. This could be an issue if a user's circumstances change (medication, life events). However:
- Would take months of use before becoming a problem
- System self-corrects as new observations come in
- Adding complexity now isn't justified

**Decision:** Note for future, don't implement now.

### No Data Migration

No existing users, no need to migrate EWMA data.

---

## Phase 1: Data Model Updates

### 1.1 Update TaskRecord.swift

**Add these fields:**

```swift
// MARK: - Classification (from AI, temp=0)

/// Engagement level classification from AI
var engagement: Engagement?

/// User override if they corrected the AI classification
var engagementUserOverride: Engagement?

/// The engagement level to use (override if present, otherwise AI)
var effectiveEngagement: Engagement? {
    engagementUserOverride ?? engagement
}

// MARK: - Baseline vs Adjusted Estimates

/// Sum of per-step AI estimates (temp=0, deterministic)
/// This is what we learn against — never changes after creation
var baselineEstimate: TimeInterval?

/// Duration bucket derived from baseline (for bucketing)
var durationBucket: DurationBucket? {
    guard let baseline = baselineEstimate else { return nil }
    return DurationBucket.from(minutes: Int(baseline / 60))
}

/// Complexity tier derived from complexity score
var complexityTier: ComplexityTier? {
    guard let c = complexity else { return nil }
    return ComplexityTier(from: c)
}
```

**Rename for clarity:**

```swift
// OLD: var predictedDuration: TimeInterval?
// NEW:
var adjustedEstimate: TimeInterval?  // After applying correction factor
```

**Remove (no longer needed with new system):**

```swift
// REMOVE: var estimateScaleFactor: Double?
// (Correction is now looked up dynamically, not stored per-task)
```

---

### 1.2 Create New Enums

**File:** `Models/Enums/Engagement.swift` (new file)

```swift
import Foundation
import FoundationModels

@Generable
enum Engagement: String, Codable, CaseIterable, Sendable {
    case tedious
    case moderate
    case engaging
    case hyperfocusProne = "hyperfocus_prone"

    var displayName: String {
        switch self {
        case .tedious: return "Tedious"
        case .moderate: return "Neutral"
        case .engaging: return "Engaging"
        case .hyperfocusProne: return "Hyperfocus Risk"
        }
    }

    var emoji: String {
        switch self {
        case .tedious: return "😴"
        case .moderate: return "😐"
        case .engaging: return "😊"
        case .hyperfocusProne: return "🎯"
        }
    }

    /// Population prior for ADHD users
    var defaultCorrectionFactor: Double {
        switch self {
        case .tedious: return 1.6
        case .moderate: return 1.3
        case .engaging: return 1.2
        case .hyperfocusProne: return 2.0
        }
    }

    var defaultVariance: Double {
        switch self {
        case .tedious: return 0.3
        case .moderate: return 0.25
        case .engaging: return 0.3
        case .hyperfocusProne: return 0.5
        }
    }
}
```

**File:** `Models/Enums/DurationBucket.swift` (new file)

```swift
import Foundation

enum DurationBucket: String, Codable, CaseIterable, Sendable {
    case veryShort = "0-15"
    case short = "15-30"
    case medium = "30-60"
    case long = "60-90"
    case veryLong = "90+"

    var displayName: String {
        switch self {
        case .veryShort: return "Very quick (0-15 min)"
        case .short: return "Quick (15-30 min)"
        case .medium: return "Medium (30-60 min)"
        case .long: return "Long (60-90 min)"
        case .veryLong: return "Very long (90+ min)"
        }
    }

    static func from(minutes: Int) -> DurationBucket {
        switch minutes {
        case 0..<15: return .veryShort
        case 15..<30: return .short
        case 30..<60: return .medium
        case 60..<90: return .long
        default: return .veryLong
        }
    }
}
```

**File:** `Models/Enums/ComplexityTier.swift` (new file)

```swift
import Foundation

enum ComplexityTier: String, Codable, CaseIterable, Sendable {
    case simple
    case moderate
    case complex

    init(from complexity: Int) {
        switch complexity {
        case 1...3: self = .simple
        case 4...7: self = .moderate
        default: self = .complex
        }
    }
}
```

---

### 1.3 Update SubtaskRecord.swift

**Simplify — remove time display support:**

```swift
@Model
final class SubtaskRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var baselineMinutes: Int      // Renamed from estimatedMinutes; for total calculation, not displayed
    var difficulty: Difficulty    // Displayed as visual indicator only
    var orderIndex: Int
    var isComplete: Bool

    var task: TaskRecord?

    // REMOVED: scaledEstimateMinutes computed property
    // REMOVED: adjustedMinutes(using:) method

    init(
        title: String,
        baselineMinutes: Int = 10,
        difficulty: Difficulty = .medium,
        orderIndex: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.baselineMinutes = baselineMinutes
        self.difficulty = difficulty
        self.orderIndex = orderIndex
        self.isComplete = false
    }
}
```

---

### 1.4 Create CorrectionFactor Model (NEW)

**File:** `Models/CorrectionFactor.swift` (new file)

```swift
import Foundation
import SwiftData

@Model
final class CorrectionFactor {
    /// Unique bucket key, e.g., "tedious|15-30|cleaning|simple"
    @Attribute(.unique) var bucketKey: String

    // MARK: - Bayesian Parameters

    /// Population prior mean (based on engagement)
    var priorMean: Double

    /// Population prior variance
    var priorVariance: Double

    /// Number of observations in this bucket
    var observationCount: Int

    /// Sum of observed ratios (for incremental mean calculation)
    var sumOfRatios: Double

    /// Sum of squared ratios (for variance calculation, future use)
    var sumOfSquaredRatios: Double

    /// When this bucket was last updated
    var lastUpdated: Date

    // MARK: - Computed Properties

    /// Posterior mean using Bayesian update
    /// Shrinks toward prior when data is sparse, toward observed mean when data is rich
    var posteriorMean: Double {
        guard observationCount > 0 else { return priorMean }
        let observedMean = sumOfRatios / Double(observationCount)
        let weight = Double(observationCount) / (Double(observationCount) + (1.0 / priorVariance))
        return weight * observedMean + (1 - weight) * priorMean
    }

    var confidence: ConfidenceLevel {
        switch observationCount {
        case 0..<3: return .veryLow
        case 3..<6: return .low
        case 6..<12: return .medium
        case 12..<20: return .good
        default: return .high
        }
    }

    // MARK: - Initialization

    init(bucketKey: String, engagement: Engagement) {
        self.bucketKey = bucketKey
        self.priorMean = engagement.defaultCorrectionFactor
        self.priorVariance = engagement.defaultVariance
        self.observationCount = 0
        self.sumOfRatios = 0
        self.sumOfSquaredRatios = 0
        self.lastUpdated = Date()
    }

    // MARK: - Update

    func addObservation(ratio: Double) {
        observationCount += 1
        sumOfRatios += ratio
        sumOfSquaredRatios += ratio * ratio
        lastUpdated = Date()
    }
}

// MARK: - Confidence Level

enum ConfidenceLevel: Int, Comparable, CaseIterable, Sendable {
    case veryLow = 0   // 0-2 observations
    case low = 1       // 3-5 observations
    case medium = 2    // 6-11 observations
    case good = 3      // 12-19 observations
    case high = 4      // 20+ observations

    static func < (lhs: ConfidenceLevel, rhs: ConfidenceLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayText: String {
        switch self {
        case .veryLow: return "rough guess"
        case .low: return "learning your pace"
        case .medium: return "based on a few tasks"
        case .good: return "based on your history"
        case .high: return "well calibrated"
        }
    }

    /// Range multiplier for time estimates (wider when less confident)
    var rangeMultiplier: Double {
        switch self {
        case .veryLow: return 0.35  // ±35%
        case .low: return 0.25      // ±25%
        case .medium: return 0.20   // ±20%
        case .good: return 0.15     // ±15%
        case .high: return 0.10     // ±10%
        }
    }
}
```

---

### 1.5 Update TaskBreakdown.swift

**Split into separate @Generable structs:**

**Keep (but modify):**

```swift
/// Breakdown output — steps only, NO time estimates
@Generable
struct TaskBreakdown {
    @Guide(description: "The main task being broken down")
    let taskName: String

    @Guide(description: "Individual action steps as clear descriptions, ordered from first to last")
    let steps: [String]  // Changed from [TaskStep] to [String] — just descriptions
}
```

**Remove:**

```swift
// REMOVE: TaskStep struct (was combining description + time + difficulty)
// REMOVE: complexity and category from TaskBreakdown (moves to classification)
// REMOVE: totalMinutes computed property
```

**Add new struct:**

```swift
/// Classification output — deterministic (temp=0)
@Generable
struct TaskClassification {
    @Guide(description: "How engaging this task typically is for someone with ADHD")
    let engagement: Engagement

    @Guide(description: "Overall complexity 1-10", .range(1...10))
    let complexity: Int

    let category: TaskCategory
}
```

**Add new struct:**

```swift
/// Single step time estimate — deterministic (temp=0)
@Generable
struct StepEstimate {
    @Guide(description: "Estimated minutes for this step", .range(1...120))
    let minutes: Int

    let difficulty: Difficulty
}
```

---

## Phase 2: Service Layer Changes

### 2.1 Update TaskBreakdownService.swift

**Rename method and change behavior:**

```swift
/// Generates creative breakdown — steps only, no times
/// Temperature: default (allows variance)
func generateBreakdown(_ description: String) async throws -> TaskBreakdown {
    let systemPrompt = """
        You are a supportive task assistant for people who work best with small, clear steps.

        Guidelines:
        - Each step should be ONE clear action (not multiple actions combined)
        - Steps should be in logical order
        - Include "getting started" steps (gather supplies, open app)
        - Use encouraging, specific language
        - Return ONLY step descriptions, not time estimates
        """

    let session = LanguageModelSession { systemPrompt }

    return try await session.respond(
        to: "Break down this task into manageable steps: \(description)",
        generating: TaskBreakdown.self
    ).content
}
```

**Add new method:**

```swift
/// Classifies task — deterministic (temp=0)
func classifyTask(description: String, steps: [String]) async throws -> TaskClassification {
    let systemPrompt = """
        Classify this task for someone with ADHD.

        Engagement levels:
        - tedious: repetitive, low novelty, minimal decisions (filing, data entry, routine chores)
        - moderate: neutral engagement, neither boring nor exciting
        - engaging: novel, challenging, or personally meaningful
        - hyperfocus_prone: high interest, creative, could lose track of time (coding, gaming, research)

        Consider the overall task and all its steps when classifying.
        """

    let session = LanguageModelSession(
        instructions: systemPrompt,
        samplingParameters: .init(temperature: 0)  // CRITICAL: deterministic
    )

    let prompt = """
        Task: \(description)
        Steps: \(steps.joined(separator: ", "))
        """

    return try await session.respond(
        to: prompt,
        generating: TaskClassification.self
    ).content
}
```

**Add new method:**

```swift
/// Estimates time for a single step — deterministic (temp=0)
func estimateStep(taskDescription: String, stepDescription: String) async throws -> StepEstimate {
    let systemPrompt = """
        Estimate how long this step will take in minutes.
        Consider the context of the overall task.
        Be realistic, not optimistic.
        """

    let session = LanguageModelSession(
        instructions: systemPrompt,
        samplingParameters: .init(temperature: 0)  // CRITICAL: deterministic
    )

    let prompt = """
        Task: \(taskDescription)
        Step: \(stepDescription)
        """

    return try await session.respond(
        to: prompt,
        generating: StepEstimate.self
    ).content
}

/// Estimates all steps — convenience method
func estimateAllSteps(taskDescription: String, steps: [String]) async throws -> [StepEstimate] {
    var estimates: [StepEstimate] = []
    for step in steps {
        let estimate = try await estimateStep(taskDescription: taskDescription, stepDescription: step)
        estimates.append(estimate)
    }
    return estimates
}
```

---

### 2.2 Replace TimeEstimationService.swift (FULL REWRITE)

```swift
import Foundation
import SwiftData

@MainActor
@Observable
final class TimeEstimationService {

    static let shared = TimeEstimationService()

    private var modelContext: ModelContext?

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Estimate Calculation

    func calculateAdjustedEstimate(
        baselineMinutes: Int,
        engagement: Engagement,
        category: TaskCategory,
        complexity: Int
    ) -> AdjustedEstimate {
        let durationBucket = DurationBucket.from(minutes: baselineMinutes)
        let complexityTier = ComplexityTier(from: complexity)

        let (factor, source, confidence) = getCorrectionFactor(
            engagement: engagement,
            durationBucket: durationBucket,
            category: category,
            complexityTier: complexityTier
        )

        let adjustedMinutes = Int(round(Double(baselineMinutes) * factor))

        // Range width based on confidence
        let rangeMultiplier = confidence.rangeMultiplier
        let rangeLow = max(1, Int(Double(adjustedMinutes) * (1 - rangeMultiplier)))
        let rangeHigh = Int(Double(adjustedMinutes) * (1 + rangeMultiplier))

        return AdjustedEstimate(
            minutes: adjustedMinutes,
            rangeLow: rangeLow,
            rangeHigh: rangeHigh,
            correctionFactor: factor,
            source: source,
            confidence: confidence
        )
    }

    // MARK: - Correction Factor Lookup with Fallback

    private func getCorrectionFactor(
        engagement: Engagement,
        durationBucket: DurationBucket,
        category: TaskCategory,
        complexityTier: ComplexityTier,
        minimumObservations: Int = 3
    ) -> (factor: Double, source: String, confidence: ConfidenceLevel) {

        let fallbackKeys = buildFallbackKeys(
            engagement: engagement,
            durationBucket: durationBucket,
            category: category,
            complexityTier: complexityTier
        )

        for key in fallbackKeys {
            if let factor = fetchFactor(key: key),
               factor.observationCount >= minimumObservations {
                return (
                    factor.posteriorMean,
                    describeSource(key: key, count: factor.observationCount),
                    factor.confidence
                )
            }
        }

        // Population baseline
        return (
            engagement.defaultCorrectionFactor,
            "estimated for ADHD",
            .veryLow
        )
    }

    private func buildFallbackKeys(
        engagement: Engagement,
        durationBucket: DurationBucket,
        category: TaskCategory,
        complexityTier: ComplexityTier
    ) -> [String] {
        let e = engagement.rawValue
        let d = durationBucket.rawValue
        let c = category.rawValue
        let x = complexityTier.rawValue

        return [
            "\(e)|\(d)|\(c)|\(x)",   // Level 5: Full specificity
            "\(e)|\(d)|\(c)|*",      // Level 4: Drop complexity
            "\(e)|\(d)|*|*",         // Level 3: Engagement + duration
            "*|\(d)|*|*",            // Level 2: Duration only (most transferable)
            "*|*|*|*"                // Level 1: User global
        ]
    }

    private func fetchFactor(key: String) -> CorrectionFactor? {
        guard let context = modelContext else { return nil }
        let descriptor = FetchDescriptor<CorrectionFactor>(
            predicate: #Predicate { $0.bucketKey == key }
        )
        return try? context.fetch(descriptor).first
    }

    private func describeSource(key: String, count: Int) -> String {
        let parts = key.split(separator: "|").map(String.init)
        guard parts.count == 4 else { return "Based on \(count) tasks" }

        let engagement = parts[0]
        let duration = parts[1]
        let category = parts[2]

        if category != "*" && engagement != "*" {
            return "Based on \(count) similar \(category) tasks"
        } else if engagement != "*" && duration != "*" {
            return "Based on your \(engagement) \(duration) min tasks"
        } else if duration != "*" {
            return "Based on your \(duration) min tasks"
        } else {
            return "Based on \(count) of your completed tasks"
        }
    }

    // MARK: - Learning (Record Completion)

    func recordCompletion(task: TaskRecord) {
        guard let context = modelContext,
              let actual = task.actualDuration,
              let baseline = task.baselineEstimate,
              baseline > 0,
              let engagement = task.effectiveEngagement,
              let durationBucket = task.durationBucket,
              let category = task.category,
              let complexityTier = task.complexityTier else {
            return
        }

        let ratio = actual / baseline

        // Update ALL fallback levels with this observation
        let keys = buildFallbackKeys(
            engagement: engagement,
            durationBucket: durationBucket,
            category: category,
            complexityTier: complexityTier
        )

        for key in keys {
            let factor = getOrCreateFactor(key: key, engagement: engagement)
            factor.addObservation(ratio: ratio)
        }

        try? context.save()
    }

    private func getOrCreateFactor(key: String, engagement: Engagement) -> CorrectionFactor {
        if let existing = fetchFactor(key: key) {
            return existing
        }

        let newFactor = CorrectionFactor(bucketKey: key, engagement: engagement)
        modelContext?.insert(newFactor)
        return newFactor
    }
}

// MARK: - Supporting Types

struct AdjustedEstimate: Equatable, Sendable {
    let minutes: Int
    let rangeLow: Int
    let rangeHigh: Int
    let correctionFactor: Double
    let source: String
    let confidence: ConfidenceLevel

    var duration: TimeInterval {
        TimeInterval(minutes * 60)
    }

    /// Primary display — always show range, never point estimate
    var displayText: String {
        if rangeLow == rangeHigh {
            return "~\(rangeLow) min"
        }
        return "\(rangeLow)–\(rangeHigh) min"
    }

    /// Friendly version for UI
    var friendlyText: String {
        "This might take you \(rangeLow)–\(rangeHigh) minutes"
    }
}
```

---

### 2.3 Delete EWMAEstimator.swift

The entire file is replaced by the CorrectionFactor model + TimeEstimationService logic.

**Also delete:** `UserDefaultsEWMAStorage` (or the protocol/implementation in EWMAEstimator.swift)

---

## Phase 3: Task Creation Flow Updates

### 3.1 Task Creation ViewModel (NEW or UPDATE)

**File:** `ViewModels/TaskCreationViewModel.swift`

```swift
import Foundation
import SwiftData

@MainActor
@Observable
class TaskCreationViewModel {
    // Input
    var taskDescription: String = ""

    // Breakdown state
    var steps: [String] = []
    var isGeneratingBreakdown = false

    // Classification state (runs in background during step editing)
    var classification: TaskClassification?
    var isClassifying = false
    var userEngagementOverride: Engagement?

    // Estimation state (runs in background during confirmation)
    var stepEstimates: [StepEstimate]?
    var adjustedEstimate: AdjustedEstimate?
    var isEstimating = false

    private let breakdownService: TaskBreakdownService
    private let estimationService: TimeEstimationService

    init(breakdownService: TaskBreakdownService, estimationService: TimeEstimationService = .shared) {
        self.breakdownService = breakdownService
        self.estimationService = estimationService
    }

    // MARK: - Phase 1: Generate Breakdown

    func generateBreakdown() async throws {
        isGeneratingBreakdown = true
        defer { isGeneratingBreakdown = false }

        let breakdown = try await breakdownService.generateBreakdown(taskDescription)
        steps = breakdown.steps

        // Immediately start classification in background
        Task { await classifyInBackground() }
    }

    // MARK: - Phase 2: Classify (runs while user edits steps)

    private func classifyInBackground() async {
        isClassifying = true
        defer { isClassifying = false }

        classification = try? await breakdownService.classifyTask(
            description: taskDescription,
            steps: steps
        )
    }

    // MARK: - Phase 3: User confirms classification, start estimation

    func userConfirmedClassification() {
        // Start estimation in background
        Task { await estimateInBackground() }
    }

    private func estimateInBackground() async {
        isEstimating = true
        defer { isEstimating = false }

        guard let classification else { return }

        stepEstimates = try? await breakdownService.estimateAllSteps(
            taskDescription: taskDescription,
            steps: steps
        )

        // Calculate adjusted estimate once we have step estimates
        if let estimates = stepEstimates {
            let baselineMinutes = estimates.reduce(0) { $0 + $1.minutes }
            let engagement = userEngagementOverride ?? classification.engagement

            adjustedEstimate = estimationService.calculateAdjustedEstimate(
                baselineMinutes: baselineMinutes,
                engagement: engagement,
                category: classification.category,
                complexity: classification.complexity
            )
        }
    }

    // MARK: - Phase 4: Create Task

    func createTask(in context: ModelContext) async -> TaskRecord? {
        // Wait for estimation if still running
        while isEstimating {
            try? await Task.sleep(for: .milliseconds(100))
        }

        guard let classification,
              let stepEstimates,
              let adjustedEstimate else {
            return nil
        }

        let task = TaskRecord(taskDescription: taskDescription)
        task.engagement = classification.engagement
        task.engagementUserOverride = userEngagementOverride
        task.category = classification.category
        task.complexity = classification.complexity

        let baselineMinutes = stepEstimates.reduce(0) { $0 + $1.minutes }
        task.baselineEstimate = TimeInterval(baselineMinutes * 60)
        task.adjustedEstimate = adjustedEstimate.duration

        // Create subtasks
        for (index, step) in steps.enumerated() {
            let subtask = SubtaskRecord(
                title: step,
                baselineMinutes: stepEstimates[index].minutes,
                difficulty: stepEstimates[index].difficulty,
                orderIndex: index
            )
            subtask.task = task
            task.subtasks.append(subtask)
        }

        context.insert(task)
        return task
    }

    // MARK: - User Actions

    func userEditedSteps(newSteps: [String]) {
        steps = newSteps
        // Re-run classification with updated steps
        Task { await classifyInBackground() }
    }

    func userChangedEngagement(to engagement: Engagement) {
        userEngagementOverride = engagement
        // Recalculate estimate with new engagement
        if let classification, let estimates = stepEstimates {
            let baselineMinutes = estimates.reduce(0) { $0 + $1.minutes }
            adjustedEstimate = estimationService.calculateAdjustedEstimate(
                baselineMinutes: baselineMinutes,
                engagement: engagement,
                category: classification.category,
                complexity: classification.complexity
            )
        }
    }
}
```

---

## Phase 4: UI Updates

### 4.1 "Look Good?" Confirmation View (NEW)

**File:** `Views/TaskCreation/TaskConfirmationView.swift`

```swift
import SwiftUI

struct TaskConfirmationView: View {
    @Bindable var viewModel: TaskCreationViewModel
    let onConfirm: () -> Void
    let onEditSteps: () -> Void
    let onEditClassification: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("Look Good?")
                .font(DesignSystem.Typography.title)
                .foregroundStyle(DesignSystem.Colors.text)

            // Classification summary
            if let classification = viewModel.classification {
                ClassificationSummaryView(
                    classification: classification,
                    engagementOverride: viewModel.userEngagementOverride
                )
            }

            // Time estimate (shows when ready)
            if let estimate = viewModel.adjustedEstimate {
                TimeEstimateView(estimate: estimate)
            } else if viewModel.isEstimating {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Calculating time...")
                        .font(DesignSystem.Typography.callout)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }

            Spacer()

            // Actions
            VStack(spacing: 12) {
                GentleButton("Yes, let's go", icon: "checkmark", style: .primary) {
                    onConfirm()
                }

                GentleButton("Change classification", style: .subtle) {
                    onEditClassification()
                }

                GentleButton("Edit steps", style: .subtle) {
                    onEditSteps()
                }
            }
        }
        .padding()
        .onAppear {
            viewModel.userConfirmedClassification()
        }
    }
}

struct ClassificationSummaryView: View {
    let classification: TaskClassification
    let engagementOverride: Engagement?

    private var effectiveEngagement: Engagement {
        engagementOverride ?? classification.engagement
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label(classification.category.displayName, systemImage: "tag")
                Spacer()
                Label(effectiveEngagement.displayName, systemImage: "sparkles")
            }
            .font(DesignSystem.Typography.body)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .padding()
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TimeEstimateView: View {
    let estimate: AdjustedEstimate

    var body: some View {
        VStack(spacing: 8) {
            Text(estimate.displayText)
                .font(DesignSystem.Typography.largeTitle)
                .foregroundStyle(DesignSystem.Colors.text)

            Text(estimate.source)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .padding()
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

### 4.2 Classification Editor View (NEW)

**File:** `Views/TaskCreation/ClassificationEditorView.swift`

```swift
import SwiftUI

struct ClassificationEditorView: View {
    let classification: TaskClassification
    @Binding var selectedEngagement: Engagement?
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("How does this task feel to you?")
                    .font(DesignSystem.Typography.headline)

                Text("This helps estimate time more accurately")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                // Engagement options
                VStack(spacing: 12) {
                    ForEach(Engagement.allCases, id: \.self) { engagement in
                        EngagementOptionRow(
                            engagement: engagement,
                            isSelected: (selectedEngagement ?? classification.engagement) == engagement,
                            isAISuggestion: engagement == classification.engagement
                        ) {
                            selectedEngagement = engagement
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Edit Classification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone() }
                }
            }
        }
    }
}

struct EngagementOptionRow: View {
    let engagement: Engagement
    let isSelected: Bool
    let isAISuggestion: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(engagement.emoji)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(engagement.displayName)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.text)

                    if isAISuggestion {
                        Text("suggested")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignSystem.Colors.primary)
                }
            }
            .padding()
            .background(isSelected ? DesignSystem.Colors.primary.opacity(0.1) : DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
```

### 4.3 Update SubtaskRowView (Simplify)

```swift
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

            // Title only — NO TIME
            Text(subtask.title)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(
                    subtask.isComplete
                        ? DesignSystem.Colors.textSecondary
                        : DesignSystem.Colors.text
                )
                .strikethrough(subtask.isComplete)

            Spacer()

            // Difficulty indicator (optional)
            DifficultyIndicator(difficulty: subtask.difficulty)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DifficultyIndicator: View {
    let difficulty: Difficulty

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    private var color: Color {
        switch difficulty {
        case .easy: return DesignSystem.Colors.gentle
        case .medium: return DesignSystem.Colors.neutral
        case .hard: return DesignSystem.Colors.primary
        }
    }
}
```

---

## Phase 5: Completion Flow Updates

### 5.1 Update CompletionPromptView.swift

**Change from:**
```swift
TimeEstimationService.shared.recordCompletion(
    actualDuration: actualDuration,
    category: category,
    originalEstimate: originalEstimate
)
```

**To:**
```swift
TimeEstimationService.shared.recordCompletion(task: task)
// The service now reads all dimensions from the task itself
```

---

## Phase 6: App Configuration

### 6.1 Add CorrectionFactor to ModelContainer

In your app setup:

```swift
let schema = Schema([
    TaskRecord.self,
    SubtaskRecord.self,
    CorrectionFactor.self  // ADD THIS
])
```

### 6.2 Configure TimeEstimationService on Launch

```swift
@main
struct FocusFlowApp: App {
    let container: ModelContainer

    init() {
        // ... existing setup ...
        TimeEstimationService.shared.configure(with: container.mainContext)
    }
}
```

### 6.3 Files to Delete

- `Utilities/EWMAEstimator.swift` (entire file)

---

## Summary: Files Changed

| File | Action |
|------|--------|
| `Models/TaskRecord.swift` | Modify (add fields, rename, remove) |
| `Models/SubtaskRecord.swift` | Modify (simplify, rename field, remove computed) |
| `Models/TaskBreakdown.swift` | Modify (split structs, remove times) |
| `Models/CorrectionFactor.swift` | **CREATE** |
| `Models/Enums/Engagement.swift` | **CREATE** |
| `Models/Enums/DurationBucket.swift` | **CREATE** |
| `Models/Enums/ComplexityTier.swift` | **CREATE** |
| `Services/TaskBreakdownService.swift` | Modify (add methods, change existing) |
| `Services/TimeEstimationService.swift` | **FULL REWRITE** |
| `Utilities/EWMAEstimator.swift` | **DELETE** |
| `ViewModels/TaskCreationViewModel.swift` | **CREATE** |
| `Views/TaskCreation/TaskConfirmationView.swift` | **CREATE** |
| `Views/TaskCreation/ClassificationEditorView.swift` | **CREATE** |
| `Views/TaskDetail/SubtaskRowView.swift` | Modify (remove time display) |
| `Views/TaskDetail/CompletionPromptView.swift` | Modify (simplify call) |
| `FocusFlowApp.swift` | Modify (configure service, update schema) |

---

## Implementation Order

1. **Create new enums** (Engagement, DurationBucket, ComplexityTier)
2. **Create CorrectionFactor model**
3. **Update TaskRecord** (add fields, rename)
4. **Update SubtaskRecord** (simplify, rename field)
5. **Update TaskBreakdown.swift** (split structs)
6. **Rewrite TimeEstimationService**
7. **Update TaskBreakdownService** (add new methods)
8. **Update ModelContainer schema**
9. **Create TaskCreationViewModel**
10. **Create TaskConfirmationView and ClassificationEditorView**
11. **Update SubtaskRowView** (remove time display)
12. **Update task creation flow in TaskListView**
13. **Update CompletionPromptView**
14. **Delete EWMAEstimator**
15. **Test end-to-end**
