//
//  TaskBreakdownTests.swift
//  FocusFlowTests
//
//  Tests for TaskBreakdown model and TaskBreakdownService.
//

import Testing
@testable import FocusFlow

@Suite("TaskBreakdown Model")
struct TaskBreakdownModelTests {

    @Test("TaskStep initializes with all properties")
    func taskStep_init_setsAllProperties() {
        let step = TaskStep(
            description: "Gather cleaning supplies",
            estimatedMinutes: 5,
            difficulty: .easy
        )

        #expect(step.description == "Gather cleaning supplies")
        #expect(step.estimatedMinutes == 5)
        #expect(step.difficulty == .easy)
    }

    @Test("TaskBreakdown initializes with all properties")
    func taskBreakdown_init_setsAllProperties() {
        let steps = [
            TaskStep(description: "Step 1", estimatedMinutes: 10, difficulty: .easy),
            TaskStep(description: "Step 2", estimatedMinutes: 15, difficulty: .medium)
        ]

        let breakdown = TaskBreakdown(
            taskName: "Clean the kitchen",
            steps: steps,
            totalMinutes: 25,
            complexity: 4,
            category: .cleaning
        )

        #expect(breakdown.taskName == "Clean the kitchen")
        #expect(breakdown.steps.count == 2)
        #expect(breakdown.totalMinutes == 25)
        #expect(breakdown.complexity == 4)
        #expect(breakdown.category == .cleaning)
    }
}

@Suite("TaskBreakdownError")
struct TaskBreakdownErrorTests {

    @Test("notAvailable error includes reason")
    func notAvailable_includesReason() {
        let error = TaskBreakdownError.notAvailable("Device not supported")

        #expect(error.errorDescription == "Device not supported")
    }

    @Test("generationFailed has user-friendly message")
    func generationFailed_hasUserFriendlyMessage() {
        let error = TaskBreakdownError.generationFailed

        #expect(error.errorDescription == "Couldn't break down that task. Try rephrasing it?")
    }
}

@Suite("UserPace")
struct UserPaceTests {

    @Test("All cases have display names")
    func displayName_allCasesHaveValues() {
        for pace in UserPace.allCases {
            #expect(!pace.displayName.isEmpty)
        }
    }

    @Test("Display names are user-friendly")
    func displayName_isUserFriendly() {
        #expect(UserPace.slower.displayName == "I like extra buffer time")
        #expect(UserPace.average.displayName == "About average")
        #expect(UserPace.faster.displayName == "I work pretty quickly")
    }

    @Test("Raw values are suitable for persistence")
    func rawValue_isSuitableForPersistence() {
        #expect(UserPace.slower.rawValue == "slower")
        #expect(UserPace.average.rawValue == "average")
        #expect(UserPace.faster.rawValue == "faster")
    }
}

@Suite("TaskBreakdownService")
@MainActor
struct TaskBreakdownServiceTests {

    @Test("Service initializes with correct default state")
    func init_hasCorrectDefaults() {
        let service = TaskBreakdownService()

        #expect(service.isProcessing == false)
        #expect(service.lastError == nil)
    }

    @Test("Breaks down task with valid output structure")
    func breakdownTask_returnsValidStructure() async throws {
        let service = TaskBreakdownService()
        try #require(service.isAvailable, "Apple Intelligence unavailable")

        let breakdown = try await service.breakdownTask("Clean the kitchen")

        #expect(!breakdown.taskName.isEmpty)
        #expect(!breakdown.steps.isEmpty)
        #expect(breakdown.totalMinutes >= 1 && breakdown.totalMinutes <= 480)
        #expect(breakdown.complexity >= 1 && breakdown.complexity <= 10)
        #expect(TaskCategory.allCases.contains(breakdown.category))

        for step in breakdown.steps {
            #expect(!step.description.isEmpty)
            #expect(step.estimatedMinutes >= 1 && step.estimatedMinutes <= 120)
            #expect(Difficulty.allCases.contains(step.difficulty))
        }
    }

    @Test("Sets isProcessing during breakdown")
    func breakdownTask_setsIsProcessing() async throws {
        let service = TaskBreakdownService()
        try #require(service.isAvailable, "Apple Intelligence unavailable")

        #expect(service.isProcessing == false)

        // Start task but don't await immediately
        async let breakdown = service.breakdownTask("Make a sandwich")

        // Give it a moment to start
        try await Task.sleep(for: .milliseconds(50))
        #expect(service.isProcessing == true)

        // Now await completion
        _ = try await breakdown
        #expect(service.isProcessing == false)
    }
}
