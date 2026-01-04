//
//  SubtaskRecordTests.swift
//  FocusFlowTests
//
//  Unit tests for SubtaskRecord model.
//

import Testing
import SwiftData
@testable import FocusFlow

@Suite("SubtaskRecord")
struct SubtaskRecordTests {

    @Test("Initializer sets default values correctly")
    func init_setsDefaultValues() {
        let subtask = SubtaskRecord(title: "Gather supplies")

        #expect(subtask.title == "Gather supplies")
        #expect(subtask.estimatedMinutes == 10)
        #expect(subtask.difficulty == .medium)
        #expect(subtask.orderIndex == 0)
        #expect(subtask.isComplete == false)
        #expect(subtask.task == nil)
    }

    @Test("Initializer accepts custom values")
    func init_acceptsCustomValues() {
        let subtask = SubtaskRecord(
            title: "Write introduction",
            estimatedMinutes: 20,
            difficulty: .hard,
            orderIndex: 3
        )

        #expect(subtask.title == "Write introduction")
        #expect(subtask.estimatedMinutes == 20)
        #expect(subtask.difficulty == .hard)
        #expect(subtask.orderIndex == 3)
    }

    @Test("Each subtask gets a unique ID")
    func init_generatesUniqueIds() {
        let subtask1 = SubtaskRecord(title: "Step 1")
        let subtask2 = SubtaskRecord(title: "Step 2")

        #expect(subtask1.id != subtask2.id)
    }

    @Test("scaledEstimateMinutes returns AI estimate when no scale factor")
    func scaledEstimate_noScaleFactor_returnsOriginal() {
        let subtask = SubtaskRecord(title: "Test", estimatedMinutes: 20)
        // No parent task, so no scale factor
        #expect(subtask.scaledEstimateMinutes == 20)
    }

    @Test("scaledEstimateMinutes applies parent's scale factor")
    func scaledEstimate_appliesScaleFactor() {
        let task = TaskRecord(taskDescription: "Parent")
        task.estimateScaleFactor = 0.8  // User is 20% faster

        let subtask = SubtaskRecord(title: "Test", estimatedMinutes: 20)
        subtask.task = task

        // 20 * 0.8 = 16
        #expect(subtask.scaledEstimateMinutes == 16)
    }

    @Test("scaledEstimateMinutes never goes below 1")
    func scaledEstimate_minimumIsOne() {
        let task = TaskRecord(taskDescription: "Parent")
        task.estimateScaleFactor = 0.1  // Very fast

        let subtask = SubtaskRecord(title: "Test", estimatedMinutes: 2)
        subtask.task = task

        // 2 * 0.1 = 0.2, rounds to 0, but minimum is 1
        #expect(subtask.scaledEstimateMinutes == 1)
    }

    @Test("scaledEstimateMinutes rounds correctly")
    func scaledEstimate_roundsCorrectly() {
        let task = TaskRecord(taskDescription: "Parent")
        task.estimateScaleFactor = 1.25  // 25% slower

        let subtask = SubtaskRecord(title: "Test", estimatedMinutes: 10)
        subtask.task = task

        // 10 * 1.25 = 12.5, rounds to 13
        #expect(subtask.scaledEstimateMinutes == 13)
    }
}

@Suite("SubtaskRecord Persistence")
struct SubtaskRecordPersistenceTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([TaskRecord.self, SubtaskRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("Subtask links to parent task correctly")
    func subtask_linksToParent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let task = TaskRecord(taskDescription: "Parent task")
        let subtask = SubtaskRecord(title: "Child step")
        task.subtasks.append(subtask)

        context.insert(task)
        try context.save()

        let descriptor = FetchDescriptor<SubtaskRecord>()
        let fetched = try context.fetch(descriptor).first!

        #expect(fetched.task?.taskDescription == "Parent task")
    }

    @Test("Subtask can be marked complete independently")
    func subtask_completesIndependently() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let task = TaskRecord(taskDescription: "Parent task")
        let subtask1 = SubtaskRecord(title: "Step 1", orderIndex: 0)
        let subtask2 = SubtaskRecord(title: "Step 2", orderIndex: 1)
        task.subtasks = [subtask1, subtask2]

        context.insert(task)
        try context.save()

        // Complete first subtask
        subtask1.isComplete = true
        try context.save()

        let descriptor = FetchDescriptor<SubtaskRecord>()
        let fetched = try context.fetch(descriptor)
        let sorted = fetched.sorted { $0.orderIndex < $1.orderIndex }

        #expect(sorted[0].isComplete == true)
        #expect(sorted[1].isComplete == false)
    }

    @Test("Difficulty enum persists correctly")
    func difficulty_persistsCorrectly() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let task = TaskRecord(taskDescription: "Test task")
        task.subtasks = [
            SubtaskRecord(title: "Easy step", difficulty: .easy, orderIndex: 0),
            SubtaskRecord(title: "Hard step", difficulty: .hard, orderIndex: 1)
        ]

        context.insert(task)
        try context.save()

        let descriptor = FetchDescriptor<SubtaskRecord>()
        let fetched = try context.fetch(descriptor)
        let sorted = fetched.sorted { $0.orderIndex < $1.orderIndex }

        #expect(sorted[0].difficulty == .easy)
        #expect(sorted[1].difficulty == .hard)
    }
}
