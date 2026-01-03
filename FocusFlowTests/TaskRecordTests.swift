//
//  TaskRecordTests.swift
//  FocusFlowTests
//
//  Unit tests for TaskRecord model.
//

import Testing
import SwiftData
@testable import FocusFlow
import Foundation

@Suite("TaskRecord")
struct TaskRecordTests {

    @Test("Initializer sets AI fields to nil")
    func init_setsAIFieldsToNil() {
        let task = TaskRecord(taskDescription: "Clean kitchen")

        #expect(task.taskDescription == "Clean kitchen")
        #expect(task.category == nil)
        #expect(task.complexity == nil)
        #expect(task.stepCount == nil)
        #expect(task.predictedDuration == nil)
    }

    @Test("Initializer sets status fields correctly")
    func init_setsStatusFields() {
        let task = TaskRecord(taskDescription: "Clean kitchen")

        #expect(task.isComplete == false)
        #expect(task.completedAt == nil)
        #expect(task.wasUsedForTraining == false)
        #expect(task.subtasks.isEmpty)
    }

    @Test("Initializer sets time tracking fields to nil")
    func init_setsTimeTrackingToNil() {
        let task = TaskRecord(taskDescription: "Clean kitchen")

        #expect(task.actualDuration == nil)
        #expect(task.startTime == nil)
        #expect(task.endTime == nil)
    }

    @Test("Each task gets a unique ID")
    func init_generatesUniqueIds() {
        let task1 = TaskRecord(taskDescription: "Task 1")
        let task2 = TaskRecord(taskDescription: "Task 2")

        #expect(task1.id != task2.id)
    }

    @Test("createdAt is set to current date")
    func init_setsCreatedAt() {
        let before = Date()
        let task = TaskRecord(taskDescription: "Test task")
        let after = Date()

        #expect(task.createdAt >= before)
        #expect(task.createdAt <= after)
    }

    @Test("AI fields can be populated after creation")
    func aiFields_canBePopulated() {
        let task = TaskRecord(taskDescription: "Clean kitchen")

        task.category = "cleaning"
        task.complexity = 4
        task.stepCount = 5
        task.predictedDuration = 1800

        #expect(task.category == "cleaning")
        #expect(task.complexity == 4)
        #expect(task.stepCount == 5)
        #expect(task.predictedDuration == 1800)
    }
}

@Suite("TaskRecord Persistence")
struct TaskRecordPersistenceTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([TaskRecord.self, SubtaskRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("Save and fetch task round trips correctly")
    func saveAndFetch_roundTrips() throws {
        let container = try makeContainer()
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
        let container = try makeContainer()
        let context = ModelContext(container)

        let task = TaskRecord(taskDescription: "Parent task")
        let subtask = SubtaskRecord(title: "Child step")
        task.subtasks.append(subtask)

        context.insert(task)
        try context.save()

        // Verify subtask exists
        let subtaskDescriptor = FetchDescriptor<SubtaskRecord>()
        let subtasksBefore = try context.fetch(subtaskDescriptor)
        #expect(subtasksBefore.count == 1)

        // Delete parent
        context.delete(task)
        try context.save()

        // Verify subtask was cascade deleted
        let subtasksAfter = try context.fetch(subtaskDescriptor)
        #expect(subtasksAfter.count == 0)
    }

    @Test("Multiple subtasks maintain order")
    func subtasks_maintainOrder() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let task = TaskRecord(taskDescription: "Multi-step task")
        task.subtasks = [
            SubtaskRecord(title: "Step 1", orderIndex: 0),
            SubtaskRecord(title: "Step 2", orderIndex: 1),
            SubtaskRecord(title: "Step 3", orderIndex: 2)
        ]

        context.insert(task)
        try context.save()

        let descriptor = FetchDescriptor<TaskRecord>()
        let fetched = try context.fetch(descriptor).first!

        let sortedSubtasks = fetched.subtasks.sorted { $0.orderIndex < $1.orderIndex }
        #expect(sortedSubtasks[0].title == "Step 1")
        #expect(sortedSubtasks[1].title == "Step 2")
        #expect(sortedSubtasks[2].title == "Step 3")
    }

    @Test("AI fields persist correctly")
    func aiFields_persistCorrectly() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let task = TaskRecord(taskDescription: "Test task")
        task.category = "work"
        task.complexity = 7
        task.stepCount = 3
        task.predictedDuration = 2400

        context.insert(task)
        try context.save()

        let descriptor = FetchDescriptor<TaskRecord>()
        let fetched = try context.fetch(descriptor).first!

        #expect(fetched.category == "work")
        #expect(fetched.complexity == 7)
        #expect(fetched.stepCount == 3)
        #expect(fetched.predictedDuration == 2400)
    }
}
