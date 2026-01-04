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
            complexity: 4,
            category: .cleaning
        )

        #expect(breakdown.taskName == "Clean the kitchen")
        #expect(breakdown.steps.count == 2)
        #expect(breakdown.complexity == 4)
        #expect(breakdown.category == .cleaning)
    }

    @Test("totalMinutes is computed from step estimates")
    func totalMinutes_sumsStepEstimates() {
        let steps = [
            TaskStep(description: "Step 1", estimatedMinutes: 10, difficulty: .easy),
            TaskStep(description: "Step 2", estimatedMinutes: 15, difficulty: .medium),
            TaskStep(description: "Step 3", estimatedMinutes: 5, difficulty: .easy)
        ]

        let breakdown = TaskBreakdown(
            taskName: "Test task",
            steps: steps,
            complexity: 3,
            category: .work
        )

        #expect(breakdown.totalMinutes == 30)
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

    @Test("Service reports availability status")
    func isAvailable_reportsStatus() {
        let service = TaskBreakdownService()

        // Just verify we can check availability without crashing
        _ = service.isAvailable
        _ = service.unavailabilityReason
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

    @Test("Accepts pace parameter")
    func breakdownTask_acceptsPace() async throws {
        let service = TaskBreakdownService()
        try #require(service.isAvailable, "Apple Intelligence unavailable")

        // Just verify the pace parameter is accepted
        let breakdown = try await service.breakdownTask("Make tea", pace: .faster)
        #expect(!breakdown.steps.isEmpty)
    }
}

@Suite("TaskBreakdownViewModel")
@MainActor
struct TaskBreakdownViewModelTests {

    @Test("ViewModel initializes with correct default state")
    func init_hasCorrectDefaults() {
        let viewModel = TaskBreakdownViewModel()

        #expect(viewModel.isProcessing == false)
        #expect(viewModel.lastError == nil)
        #expect(viewModel.lastBreakdown == nil)
        #expect(viewModel.userPace == .average)
    }

    @Test("ViewModel exposes service availability")
    func isAvailable_exposesServiceAvailability() {
        let viewModel = TaskBreakdownViewModel()

        // Just verify we can check availability
        _ = viewModel.isAvailable
        _ = viewModel.unavailabilityReason
    }

    @Test("Sets isProcessing during breakdown")
    func breakdownTask_setsIsProcessing() async throws {
        let viewModel = TaskBreakdownViewModel()
        try #require(viewModel.isAvailable, "Apple Intelligence unavailable")

        #expect(viewModel.isProcessing == false)

        // Start task but don't await immediately
        async let breakdown = viewModel.breakdownTask("Make a sandwich")

        // Give it a moment to start
        try await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.isProcessing == true)

        // Now await completion
        _ = try await breakdown
        #expect(viewModel.isProcessing == false)
    }

    @Test("Stores last breakdown on success")
    func breakdownTask_storesLastBreakdown() async throws {
        let viewModel = TaskBreakdownViewModel()
        try #require(viewModel.isAvailable, "Apple Intelligence unavailable")

        #expect(viewModel.lastBreakdown == nil)

        let breakdown = try await viewModel.breakdownTask("Organize desk")

        #expect(viewModel.lastBreakdown != nil)
        #expect(viewModel.lastBreakdown?.taskName == breakdown.taskName)
    }

    @Test("clearError resets lastError")
    func clearError_resetsLastError() {
        let viewModel = TaskBreakdownViewModel()

        // Can always call clearError even if no error
        viewModel.clearError()
        #expect(viewModel.lastError == nil)
    }
}
