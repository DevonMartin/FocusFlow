# FocusFlow: ADHD/Autism Cognitive Support App for iOS

## Project Overview

**FocusFlow** is an iOS app designed to help people with ADHD and autism manage tasks through AI-powered task breakdown, personalized time estimation, and guilt-free progress tracking. It uses Apple's Foundation Models framework for on-device intelligence, ensuring complete privacy.

### Core Philosophy

This app is built on the principle that **ADHD and autism are neurological differences to accommodate, not motivation problems to fix**. Every design decision should ask: "Does this reduce friction and shame, or add to it?"

### Target User

- Adults with ADHD, autism, or both (AuDHD)
- People who struggle with task initiation, time blindness, and executive function
- Users who have abandoned traditional productivity apps due to guilt/shame cycles
- Privacy-conscious users who want on-device AI

### Developer Context

The developer (Devon) has ADHD themselves, which provides authentic insight into the problem space. This is both a portfolio piece for job applications and a genuinely useful tool.

---

## Development Workflow Requirements

### ⚠️ CRITICAL: Commit Discipline

**Claude Code must NEVER run `git commit` directly.** The user commits manually. Claude Code's job is to:

1. Check for uncommitted changes with `git status`
2. Stop and alert the user when a commit checkpoint is reached
3. Provide a properly formatted commit message for the user to use
4. Wait for confirmation before proceeding

**Commit checkpoint prompts** — Claude Code should say:
- "Before we continue, here's a commit message for what we just completed:"
- "I see uncommitted changes. Here's a commit message — please commit before we proceed:"
- After completing any feature: "Good stopping point. Here's your commit message:"

Then provide the formatted message in a code block the user can copy.

### Commit Message Format

Use **Conventional Commits** with the following structure:

```
<type>(<scope>): <short description>

<body - optional, explains WHY not WHAT>

<footer - optional, references issues>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code restructuring without behavior change
- `style`: Formatting, whitespace (no code change)
- `test`: Adding or updating tests
- `docs`: Documentation only
- `chore`: Build process, dependencies, config

**Scopes for this project:**
- `tasks`: Task model, breakdown, CRUD
- `timer`: Live Activity, countdown, time tracking
- `estimation`: Time prediction, EWMA, ML pipeline
- `ui`: Views, design system, accessibility
- `data`: SwiftData models, persistence
- `foundation`: Foundation Models integration
- `tests`: Test infrastructure

**Examples:**
```
feat(tasks): add Foundation Models task breakdown with @Generable

Implements structured task analysis using Apple's Foundation Models framework.
Uses @Generable macro for type-safe output including stepCount, complexity,
category, and baselineMinutes.

feat(timer): implement Live Activity with timerInterval countdown

Uses timerInterval initializer for reliable background countdown.
Includes lock screen and Dynamic Island compact presentations.

fix(estimation): handle division by zero in EWMA calculator

Previously crashed when category had no historical data.
Now falls back to default 30-minute estimate.

test(tasks): add unit tests for TaskBreakdown parsing

Covers happy path, empty input, and malformed responses.

refactor(ui): extract color constants to DesignSystem

Centralizes ADHD-friendly color palette for consistency.
```

### Test Coverage Requirements (Swift Testing)

**Every feature must have corresponding tests before commit:**

1. **Unit Tests** — Required for:
   - All model types (TaskRecord, SubtaskRecord, etc.)
   - Business logic (EWMAEstimator, time calculations)
   - Foundation Models response parsing
   - Data transformations

2. **Integration Tests** — Required for:
   - SwiftData persistence (save, fetch, delete, update)
   - Foundation Models session lifecycle
   - Live Activity state management

3. **UI Tests** — Required for:
   - Critical user flows (create task, start timer, complete task)
   - Accessibility (VoiceOver labels, Dynamic Type)

**Test file naming:** `<FeatureName>Tests.swift`

**Swift Testing patterns:**

```swift
import Testing

@Suite("Feature Name")
struct FeatureTests {
    
    @Test("Descriptive test name")
    func methodName_scenario_expectedResult() {
        // Arrange
        // Act
        // Assert with #expect()
    }
}
```

**Before providing a commit message:**
1. Run `⌘U` to execute all tests
2. Verify new tests pass
3. Verify no regressions in existing tests

---

## Technical Architecture

### Platform Requirements

- **iOS 26+** (Foundation Models requirement)
- **iPhone 15 Pro or newer** (Apple Intelligence requirement)
- **Xcode 17+**

### Core Frameworks

| Framework | Purpose |
|-----------|---------|
| **FoundationModels** | On-device LLM for task breakdown |
| **SwiftData** | Local persistence |
| **ActivityKit** | Live Activities and Dynamic Island |
| **SwiftUI** | UI framework |
| **WidgetKit** | Lock screen widgets |

### Project Structure

```
FocusFlow/
├── App/
│   ├── FocusFlowApp.swift
│   └── ContentView.swift
├── Models/
│   ├── TaskRecord.swift
│   ├── SubtaskRecord.swift
│   ├── TaskFeatures.swift          # @Generable struct
│   └── TaskBreakdown.swift         # @Generable struct
├── Services/
│   ├── TaskBreakdownService.swift  # Foundation Models integration
│   ├── TimeEstimationService.swift # EWMA + future ML
│   └── LiveActivityManager.swift
├── Views/
│   ├── TaskList/
│   │   ├── TaskListView.swift
│   │   └── TaskRowView.swift
│   ├── TaskDetail/
│   │   ├── TaskDetailView.swift
│   │   └── SubtaskListView.swift
│   ├── Timer/
│   │   ├── ActiveTaskView.swift
│   │   └── TimerDisplayView.swift
│   └── Components/
│       ├── ProgressRing.swift
│       └── GentleButton.swift
├── DesignSystem/
│   ├── Colors.swift
│   ├── Typography.swift
│   └── Language.swift              # ADHD-friendly copy
├── LiveActivity/
│   ├── TaskTimerAttributes.swift
│   ├── TaskTimerLiveActivity.swift
│   └── FocusFlowWidgetBundle.swift
├── Utilities/
│   ├── EWMAEstimator.swift
│   └── Extensions/
└── Tests/
    ├── ModelTests/
    ├── ServiceTests/
    └── UITests/
```

---

## Data Models

### TaskRecord (SwiftData)

```swift
import SwiftData
import Foundation

@Model
final class TaskRecord {
    @Attribute(.unique) var id: UUID
    var taskDescription: String
    var category: String
    var complexity: Int  // 1-10
    var stepCount: Int
    
    // Time tracking
    var predictedDuration: TimeInterval  // seconds
    var actualDuration: TimeInterval?
    var startTime: Date?
    var endTime: Date?
    
    // Status
    var isComplete: Bool
    var createdAt: Date
    var completedAt: Date?
    
    // ML training
    var wasUsedForTraining: Bool
    
    // Relationships
    @Relationship(deleteRule: .cascade)
    var subtasks: [SubtaskRecord]
    
    init(
        taskDescription: String,
        category: String = "general",
        complexity: Int = 5,
        stepCount: Int = 1,
        predictedDuration: TimeInterval = 1800
    ) {
        self.id = UUID()
        self.taskDescription = taskDescription
        self.category = category
        self.complexity = complexity
        self.stepCount = stepCount
        self.predictedDuration = predictedDuration
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
```

### SubtaskRecord (SwiftData)

```swift
@Model
final class SubtaskRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var estimatedMinutes: Int
    var difficulty: String  // "easy", "medium", "hard"
    var orderIndex: Int
    var isComplete: Bool
    
    // Parent relationship
    var task: TaskRecord?
    
    init(
        title: String,
        estimatedMinutes: Int = 10,
        difficulty: String = "medium",
        orderIndex: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.difficulty = difficulty
        self.orderIndex = orderIndex
        self.isComplete = false
    }
}
```

### Foundation Models Generable Types

```swift
import FoundationModels

@Generable
struct TaskBreakdown {
    @Guide(description: "The main task being broken down")
    let taskName: String
    
    @Guide(description: "Individual action steps, ordered from first to last")
    let steps: [TaskStep]
    
    @Guide(description: "Total estimated minutes for average person", .range(1...480))
    let totalMinutes: Int
    
    @Guide(description: "Overall complexity 1-10", .range(1...10))
    let complexity: Int
    
    @Guide(.anyOf(["cleaning", "cooking", "organizing", "errands", "work", "self-care", "admin", "creative", "social", "other"]))
    let category: String
}

@Generable
struct TaskStep {
    @Guide(description: "Clear, actionable step description")
    let description: String
    
    @Guide(description: "Estimated minutes for this step", .range(1...120))
    let estimatedMinutes: Int
    
    @Guide(.anyOf(["easy", "medium", "hard"]))
    let difficulty: String
}
```

---

## Foundation Models Integration

### TaskBreakdownService

```swift
import FoundationModels

@MainActor
class TaskBreakdownService: ObservableObject {
    @Published var isProcessing = false
    @Published var currentPartial: TaskBreakdown.PartiallyGenerated?
    @Published var lastError: Error?
    
    private var session: LanguageModelSession?
    
    // Check device capability
    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }
    
    var unavailabilityReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support on-device AI. iPhone 15 Pro or newer required."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Please enable Apple Intelligence in Settings to use AI features."
        case .unavailable(.modelNotReady):
            return "AI model is still downloading. Please try again in a few minutes."
        @unknown default:
            return "AI features are currently unavailable."
        }
    }
    
    func breakdownTask(_ description: String) async throws -> TaskBreakdown {
        guard isAvailable else {
            throw TaskBreakdownError.notAvailable(unavailabilityReason ?? "Unknown error")
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let session = LanguageModelSession {
            """
            You are a supportive ADHD task assistant. Your job is to break down tasks into small, concrete, actionable steps.
            
            Guidelines:
            - Each step should be a single, clear action (not multiple actions)
            - Steps should be ordered logically
            - Time estimates should be realistic for someone who may need extra time
            - Use encouraging, clear language
            - Prefer shorter steps (5-15 minutes) over longer ones
            - Include "getting started" steps when relevant (gather materials, open app, etc.)
            """
        }
        
        // Stream for responsive UI
        let stream = session.streamResponse(
            to: "Break down this task into manageable steps: \(description)",
            generating: TaskBreakdown.self
        )
        
        var finalResult: TaskBreakdown?
        
        for try await partial in stream {
            self.currentPartial = partial
            if let complete = partial.asCompleteIfPossible() {
                finalResult = complete
            }
        }
        
        guard let result = finalResult else {
            throw TaskBreakdownError.generationFailed
        }
        
        return result
    }
}

enum TaskBreakdownError: LocalizedError {
    case notAvailable(String)
    case generationFailed
    
    var errorDescription: String? {
        switch self {
        case .notAvailable(let reason):
            return reason
        case .generationFailed:
            return "Couldn't break down that task. Try rephrasing it?"
        }
    }
}
```

---

## Time Estimation System

### Progressive Personalization

The system graduates through tiers as data accumulates:

| Tier | Task Count | Method |
|------|------------|--------|
| 1 | 0-9 | User estimate or LLM baseline |
| 2 | 10-49 | Category averages |
| 3 | 50-99 | Exponential Weighted Moving Average |
| 4 | 100+ | Trained MLLinearRegressor (future) |

### EWMAEstimator

```swift
import Foundation

class EWMAEstimator {
    private var categoryEstimates: [String: Double] = [:]
    private var categoryCounts: [String: Int] = [:]
    private let alpha: Double = 0.3  // Weight for recent data (higher = more reactive)
    private let defaultEstimate: Double = 1800  // 30 minutes in seconds
    
    func estimate(for category: String) -> TimeInterval {
        return categoryEstimates[category] ?? defaultEstimate
    }
    
    func update(category: String, actualDuration: TimeInterval) {
        let currentEstimate = categoryEstimates[category] ?? defaultEstimate
        let newEstimate = alpha * actualDuration + (1 - alpha) * currentEstimate
        categoryEstimates[category] = newEstimate
        categoryCounts[category, default: 0] += 1
    }
    
    func confidenceLevel(for category: String) -> ConfidenceLevel {
        let count = categoryCounts[category] ?? 0
        switch count {
        case 0..<5: return .low
        case 5..<20: return .medium
        default: return .high
        }
    }
    
    enum ConfidenceLevel {
        case low, medium, high
        
        var displayText: String {
            switch self {
            case .low: return "rough guess"
            case .medium: return "based on a few similar tasks"
            case .high: return "based on your history"
            }
        }
    }
}
```

### TimeEstimationService

```swift
@MainActor
class TimeEstimationService: ObservableObject {
    private let ewmaEstimator = EWMAEstimator()
    private var completedTaskCount: Int = 0
    
    func estimate(for task: TaskRecord, llmBaseline: Int) -> TimeEstimate {
        let category = task.category
        
        switch completedTaskCount {
        case 0..<10:
            // Tier 1: Trust LLM baseline
            return TimeEstimate(
                seconds: TimeInterval(llmBaseline * 60),
                confidence: .low,
                source: "AI estimate"
            )
            
        case 10..<50:
            // Tier 2: Category average
            let estimate = ewmaEstimator.estimate(for: category)
            return TimeEstimate(
                seconds: estimate,
                confidence: .medium,
                source: "based on similar tasks"
            )
            
        default:
            // Tier 3: EWMA with confidence
            let estimate = ewmaEstimator.estimate(for: category)
            let confidence = ewmaEstimator.confidenceLevel(for: category)
            return TimeEstimate(
                seconds: estimate,
                confidence: confidence,
                source: confidence.displayText
            )
        }
    }
    
    func recordCompletion(category: String, actualDuration: TimeInterval) {
        ewmaEstimator.update(category: category, actualDuration: actualDuration)
        completedTaskCount += 1
    }
}

struct TimeEstimate {
    let seconds: TimeInterval
    let confidence: EWMAEstimator.ConfidenceLevel
    let source: String
    
    var displayMinutes: Int {
        Int(ceil(seconds / 60))
    }
}
```

---

## Live Activity Implementation

### TaskTimerAttributes

```swift
import ActivityKit
import Foundation

struct TaskTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var taskName: String
        var currentStep: String?
        var stepIndex: Int
        var totalSteps: Int
        var isOvertime: Bool
    }
    
    var startDate: Date
    var endDate: Date
    var taskId: UUID
}
```

### TaskTimerLiveActivity

```swift
import WidgetKit
import SwiftUI
import ActivityKit

struct TaskTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TaskTimerAttributes.self) { context in
            // Lock screen presentation
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded presentation
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 8) {
                        Text(context.state.taskName)
                            .font(.headline)
                            .lineLimit(1)
                        
                        if !context.state.isOvertime {
                            Text(timerInterval: context.attributes.startDate...context.attributes.endDate, countsDown: true)
                                .font(.system(size: 36, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(DesignSystem.Colors.primary)
                        } else {
                            Text("Take your time")
                                .font(.title2)
                                .foregroundStyle(DesignSystem.Colors.gentle)
                        }
                        
                        if let step = context.state.currentStep {
                            Text(step)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "circle.dotted")
                    .foregroundStyle(DesignSystem.Colors.primary)
            } compactTrailing: {
                if !context.state.isOvertime {
                    Text(timerInterval: context.attributes.startDate...context.attributes.endDate, countsDown: true)
                        .monospacedDigit()
                        .frame(width: 50)
                        .foregroundStyle(DesignSystem.Colors.primary)
                } else {
                    Text("✓")
                        .foregroundStyle(DesignSystem.Colors.gentle)
                }
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(DesignSystem.Colors.primary)
            }
        }
    }
}

struct LockScreenView: View {
    let context: ActivityViewContext<TaskTimerAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(context.state.taskName)
                    .font(.headline)
                    .foregroundStyle(DesignSystem.Colors.text)
                
                Spacer()
                
                Text("Step \(context.state.stepIndex)/\(context.state.totalSteps)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if !context.state.isOvertime {
                // Progress bar that fills UP (not depletes)
                ProgressView(
                    timerInterval: context.attributes.startDate...context.attributes.endDate,
                    countsDown: false  // Fills up = completion framing
                ) { EmptyView() } currentValueLabel: { EmptyView() }
                .progressViewStyle(.linear)
                .tint(DesignSystem.Colors.primary)
            }
            
            HStack {
                if let step = context.state.currentStep {
                    Text(step)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if !context.state.isOvertime {
                    Text(timerInterval: context.attributes.startDate...context.attributes.endDate, countsDown: true)
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(DesignSystem.Colors.primary)
                } else {
                    Text("Ready when you are")
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.gentle)
                }
            }
        }
        .padding()
        .background(DesignSystem.Colors.background)
    }
}
```

### LiveActivityManager

```swift
import ActivityKit
import Foundation

@MainActor
class LiveActivityManager: ObservableObject {
    @Published var currentActivity: Activity<TaskTimerAttributes>?
    
    func startTimer(for task: TaskRecord, estimatedDuration: TimeInterval) throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityError.notAuthorized
        }
        
        let now = Date()
        let endDate = now.addingTimeInterval(estimatedDuration)
        
        let attributes = TaskTimerAttributes(
            startDate: now,
            endDate: endDate,
            taskId: task.id
        )
        
        let initialState = TaskTimerAttributes.ContentState(
            taskName: task.taskDescription,
            currentStep: task.subtasks.first?.title,
            stepIndex: 1,
            totalSteps: max(task.subtasks.count, 1),
            isOvertime: false
        )
        
        let content = ActivityContent(state: initialState, staleDate: endDate.addingTimeInterval(300))
        
        currentActivity = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
    }
    
    func updateStep(index: Int, stepTitle: String) async {
        guard let activity = currentActivity else { return }
        
        var state = activity.content.state
        state.stepIndex = index
        state.currentStep = stepTitle
        
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }
    
    func markOvertime() async {
        guard let activity = currentActivity else { return }
        
        var state = activity.content.state
        state.isOvertime = true
        
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }
    
    func endTimer() async {
        guard let activity = currentActivity else { return }
        
        await activity.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
    }
}

enum LiveActivityError: LocalizedError {
    case notAuthorized
    
    var errorDescription: String? {
        "Live Activities aren't enabled. You can enable them in Settings."
    }
}
```

---

## ADHD-Friendly Design System

### Colors

```swift
import SwiftUI

enum DesignSystem {
    enum Colors {
        // Primary palette - calming blues and teals
        static let primary = Color(hex: "4A90A4")      // Soft teal
        static let secondary = Color(hex: "7BB3C0")   // Light teal
        static let accent = Color(hex: "5D9B9B")      // Muted teal-green
        
        // Semantic colors
        static let gentle = Color(hex: "8FBC8F")      // Soft green for success/completion
        static let neutral = Color(hex: "B8C4CE")     // Gray-blue for neutral states
        static let warning = Color(hex: "DEB887")     // Soft tan (NOT red/orange)
        
        // Text and backgrounds
        static let text = Color(hex: "2C3E50")        // Dark blue-gray
        static let textSecondary = Color(hex: "7F8C8D")
        static let background = Color(hex: "F8FAFB")  // Very light gray-blue
        static let surface = Color.white
        
        // NEVER use these for time/progress
        // - Bright red (triggers anxiety)
        // - Neon yellow (overstimulating)
        // - Traffic light progressions (green→yellow→red)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

### Typography

```swift
extension DesignSystem {
    enum Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 28, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        
        // Monospaced for timers
        static let timer = Font.system(size: 48, weight: .medium, design: .rounded).monospacedDigit()
        static let timerSmall = Font.system(size: 28, weight: .medium, design: .rounded).monospacedDigit()
    }
}
```

### Language Patterns

```swift
extension DesignSystem {
    enum Language {
        // Time estimates - always uncertain, never demanding
        static func timeEstimate(_ minutes: Int) -> String {
            "This might take about \(minutes) minutes"
        }
        
        static func timeEstimateWithConfidence(_ minutes: Int, confidence: String) -> String {
            "About \(minutes) min (\(confidence))"
        }
        
        // Status - never shame, never "overdue"
        static let stillWorking = "Still working on it"
        static let readyWhenYouAre = "Ready when you are"
        static let takeYourTime = "Take your time"
        static let niceWork = "Nice work!"
        static let welcomeBack = "Welcome back"
        
        // Instead of "You failed to complete..."
        static let stillOnYourList = "Still on your list"
        
        // Instead of "0 days streak"
        static let getStarted = "Ready to get started?"
        
        // Task completion - same celebration regardless of timing
        static let completionMessages = [
            "Done! Nice work.",
            "That's one off your plate.",
            "Progress feels good.",
            "You did the thing!",
            "Check! What's next?"
        ]
        
        static var randomCompletionMessage: String {
            completionMessages.randomElement() ?? "Done!"
        }
        
        // Overtime handling
        static let overtimeMessage = "Taking longer than expected? That's okay—estimates are just guesses."
        
        // Re-engagement after absence (never guilt)
        static let returnMessages = [
            "Hey, welcome back!",
            "Good to see you.",
            "Ready when you are."
        ]
    }
}
```

### UI Components

```swift
// Gentle button that doesn't feel urgent
struct GentleButton: View {
    let title: String
    let action: () -> Void
    var style: Style = .primary
    
    enum Style {
        case primary, secondary, subtle
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return DesignSystem.Colors.primary
        case .subtle: return DesignSystem.Colors.textSecondary
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary: return DesignSystem.Colors.primary
        case .secondary: return DesignSystem.Colors.primary.opacity(0.1)
        case .subtle: return Color.clear
        }
    }
}

// Progress ring that fills UP (completion framing)
struct ProgressRing: View {
    let progress: Double  // 0.0 to 1.0
    var lineWidth: CGFloat = 8
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(DesignSystem.Colors.neutral.opacity(0.3), lineWidth: lineWidth)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    DesignSystem.Colors.primary,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
    }
}
```

---

## MVP Feature Scope

### ✅ Build in MVP (Weeks 1-8)

**Week 1-2: Foundation**
- [ ] Project setup with SwiftData
- [ ] TaskRecord and SubtaskRecord models
- [ ] Basic CRUD for tasks
- [ ] Design system (colors, typography, language)

**Week 3-4: AI Integration**
- [ ] Foundation Models availability checking
- [ ] TaskBreakdown @Generable implementation
- [ ] TaskBreakdownService with streaming
- [ ] Fallback for unsupported devices

**Week 5-6: Timer & Live Activity**
- [ ] Live Activity with timerInterval countdown
- [ ] Dynamic Island compact presentation
- [ ] Start/stop timer flow
- [ ] Overtime handling (graceful, not punishing)

**Week 7-8: Personalization & Polish**
- [ ] EWMAEstimator for time predictions
- [ ] Progressive tier system
- [ ] Completion tracking for learning
- [ ] UI polish and accessibility

### 🔜 Defer to v1.1

- CreateML MLLinearRegressor training
- Background retraining via BGTaskScheduler
- HealthKit sleep/productivity correlation
- Expanded Dynamic Island presentation
- Detailed analytics/insights view
- iCloud sync

### 📋 Defer to v2.0

- Apple Watch app
- Widget for home screen
- Siri shortcuts
- Body doubling features
- Social/accountability features
- Export functionality

---

## Testing Strategy

### Unit Test Examples (Swift Testing)

```swift
import Testing
@testable import FocusFlow

@Suite("EWMA Estimator")
struct EWMAEstimatorTests {
    
    @Test("Returns default estimate with no history")
    func estimate_withNoHistory_returnsDefault() {
        let estimator = EWMAEstimator()
        let estimate = estimator.estimate(for: "cleaning")
        #expect(estimate == 1800)  // 30 min default
    }
    
    @Test("Blends properly after single update")
    func estimate_afterSingleUpdate_blendsProperly() {
        var estimator = EWMAEstimator()
        estimator.update(category: "cleaning", actualDuration: 3600)  // 60 min
        let estimate = estimator.estimate(for: "cleaning")
        // With alpha=0.3: 0.3*3600 + 0.7*1800 = 2340
        #expect(abs(estimate - 2340) < 0.1)
    }
    
    @Test("Converges after multiple updates")
    func estimate_afterMultipleUpdates_converges() {
        var estimator = EWMAEstimator()
        for _ in 0..<10 {
            estimator.update(category: "cleaning", actualDuration: 2400)  // 40 min
        }
        let estimate = estimator.estimate(for: "cleaning")
        #expect(abs(estimate - 2400) < 100)  // Should converge near 40 min
    }
    
    @Test("Confidence level increases with data")
    func confidenceLevel_increasesWithData() {
        var estimator = EWMAEstimator()
        #expect(estimator.confidenceLevel(for: "cleaning") == .low)
        
        for _ in 0..<5 {
            estimator.update(category: "cleaning", actualDuration: 1800)
        }
        #expect(estimator.confidenceLevel(for: "cleaning") == .medium)
        
        for _ in 0..<15 {
            estimator.update(category: "cleaning", actualDuration: 1800)
        }
        #expect(estimator.confidenceLevel(for: "cleaning") == .high)
    }
}

@Suite("Task Record")
struct TaskRecordTests {
    
    @Test("Initializer sets default values")
    func init_setsDefaultValues() {
        let task = TaskRecord(taskDescription: "Clean kitchen")
        
        #expect(task.isComplete == false)
        #expect(task.startTime == nil)
        #expect(task.actualDuration == nil)
        #expect(task.category == "general")
        #expect(task.complexity == 5)
    }
}
```

### Integration Test Examples (Swift Testing)

```swift
import Testing
import SwiftData
@testable import FocusFlow

@Suite("Task Persistence")
struct TaskPersistenceTests {
    
    @Test("Save and fetch task round trips correctly")
    func saveAndFetchTask_roundTrips() throws {
        let schema = Schema([TaskRecord.self, SubtaskRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let task = TaskRecord(taskDescription: "Test task")
        context.insert(task)
        try context.save()
        
        let descriptor = FetchDescriptor<TaskRecord>()
        let fetched = try context.fetch(descriptor)
        
        #expect(fetched.count == 1)
        #expect(fetched.first?.taskDescription == "Test task")
    }
    
    @Test("Deleting task cascades to subtasks")
    func deleteTask_cascadesSubtasks() throws {
        let schema = Schema([TaskRecord.self, SubtaskRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let task = TaskRecord(taskDescription: "Parent")
        let subtask = SubtaskRecord(title: "Child")
        task.subtasks.append(subtask)
        
        context.insert(task)
        try context.save()
        
        context.delete(task)
        try context.save()
        
        let subtaskDescriptor = FetchDescriptor<SubtaskRecord>()
        let remainingSubtasks = try context.fetch(subtaskDescriptor)
        
        #expect(remainingSubtasks.count == 0)
    }
}
```

---

## Accessibility Requirements

Every view must support:

1. **VoiceOver** — All interactive elements need accessibility labels
2. **Dynamic Type** — Use system fonts and avoid fixed sizes
3. **Reduce Motion** — Respect `accessibilityReduceMotion`
4. **Color Contrast** — Minimum 4.5:1 for text

```swift
// Example accessible component
struct TaskRowView: View {
    let task: TaskRecord
    
    var body: some View {
        HStack {
            // ... content
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to view details")
    }
    
    private var accessibilityLabel: String {
        var label = task.taskDescription
        if task.isComplete {
            label += ", completed"
        } else {
            let minutes = Int(task.predictedDuration / 60)
            label += ", estimated \(minutes) minutes"
        }
        return label
    }
}
```

---

## Quick Reference

### When to Provide Commit Messages

Claude Code should stop and provide a commit message:
- After completing any model/struct
- After completing any service method
- After completing any view
- After adding/updating tests
- Before switching to a different feature
- Before ending a session

### Commit Checklist (User Performs)

```
[ ] All tests pass (⌘U)
[ ] No compiler warnings
[ ] Code compiles (⌘B)
[ ] Changes are logically grouped
[ ] Commit message follows format
[ ] Run: git add . && git commit -m "<message>"
```

### Key Files to Create First

1. `DesignSystem/Colors.swift`
2. `DesignSystem/Typography.swift`
3. `DesignSystem/Language.swift`
4. `Models/TaskRecord.swift`
5. `Models/SubtaskRecord.swift`
6. `Utilities/EWMAEstimator.swift`

---

## Resources

- [Foundation Models WWDC 2025](https://developer.apple.com/videos/play/wwdc2025/286/)
- [Live Activities Documentation](https://developer.apple.com/documentation/activitykit)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [W3C Cognitive Accessibility](https://www.w3.org/TR/coga-usable/)
