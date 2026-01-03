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
        #expect(subtask.difficulty == "medium")
        #expect(subtask.orderIndex == 0)
        #expect(subtask.isComplete == false)
        #expect(subtask.task == nil)
    }

    @Test("Initializer accepts custom values")
    func init_acceptsCustomValues() {
        let subtask = SubtaskRecord(
            title: "Write introduction",
            estimatedMinutes: 20,
            difficulty: "hard",
            orderIndex: 3
        )

        #expect(subtask.title == "Write introduction")
        #expect(subtask.estimatedMinutes == 20)
        #expect(subtask.difficulty == "hard")
        #expect(subtask.orderIndex == 3)
    }

    @Test("Each subtask gets a unique ID")
    func init_generatesUniqueIds() {
        let subtask1 = SubtaskRecord(title: "Step 1")
        let subtask2 = SubtaskRecord(title: "Step 2")

        #expect(subtask1.id != subtask2.id)
    }

    @Test("Difficulty accepts valid values")
    func difficulty_acceptsValidValues() {
        let easy = SubtaskRecord(title: "Easy step", difficulty: "easy")
        let medium = SubtaskRecord(title: "Medium step", difficulty: "medium")
        let hard = SubtaskRecord(title: "Hard step", difficulty: "hard")

        #expect(easy.difficulty == "easy")
        #expect(medium.difficulty == "medium")
        #expect(hard.difficulty == "hard")
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
}
