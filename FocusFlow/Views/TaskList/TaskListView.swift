//
//  TaskListView.swift
//  FocusFlow
//
//  Main task list screen with create, complete, and delete functionality.
//

import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskRecord.createdAt, order: .reverse) private var tasks: [TaskRecord]

    @State private var showingAddTask = false
    @State private var newTaskDescription = ""
    @State private var isCreatingTask = false

    private var breakdownService = TaskBreakdownService()
    private var estimationService = TimeEstimationService(
        estimator: EWMAEstimator()
    )

    #if DEBUG
    /// Initialize with AI disabled for testing fallback behavior
    init(forceAIDisabled: Bool = false) {
        if forceAIDisabled {
            breakdownService.forceDisabled = true
        }
    }
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                if tasks.isEmpty {
                    emptyState
                } else {
                    taskList
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddTask = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(DesignSystem.Colors.primary)
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                addTaskSheet
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 64))
                .foregroundStyle(DesignSystem.Colors.secondary)

            Text(DesignSystem.Language.emptyTaskList)
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.text)

            GentleButton("Add a Task", icon: "plus", style: .primary) {
                showingAddTask = true
            }
            .frame(maxWidth: 200)
        }
        .padding()
    }

    // MARK: - Task List

    private var taskList: some View {
        List {
            Section {
                ForEach(incompleteTasks) { task in
                    TaskRowView(
                        task: task,
                        onTap: { selectTask(task) },
                        onComplete: { completeTask(task) }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteTask(task)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            if !completedTasks.isEmpty {
                completedSection
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @State private var isCompletedExpanded = false

    private var completedSection: some View {
        Section(isExpanded: $isCompletedExpanded) {
            ForEach(completedTasks) { task in
                TaskRowView(
                    task: task,
                    onTap: {},
                    onComplete: { uncompleteTask(task) }
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteTask(task)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        } header: {
            Button {
                withAnimation {
                    isCompletedExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Completed (\(completedTasks.count))")
                        .font(DesignSystem.Typography.callout)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .rotationEffect(.degrees(isCompletedExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Add Task Sheet

    private var addTaskSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("What do you need to do?", text: $newTaskDescription)
                    .font(DesignSystem.Typography.body)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(DesignSystem.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .submitLabel(.done)
                    .onSubmit {
                        createTask()
                    }
                    .disabled(isCreatingTask)

                if isCreatingTask {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(DesignSystem.Colors.primary)
                        Text(DesignSystem.Language.aiProcessing)
                            .font(DesignSystem.Typography.callout)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                } else {
                    GentleButton("Add Task", icon: "plus", style: .primary) {
                        createTask()
                    }
                    .disabled(newTaskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Spacer()
            }
            .padding()
            .background(DesignSystem.Colors.background)
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newTaskDescription = ""
                        showingAddTask = false
                    }
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Computed Properties

    private var incompleteTasks: [TaskRecord] {
        tasks.filter { !$0.isComplete }
    }

    private var completedTasks: [TaskRecord] {
        tasks.filter { $0.isComplete }
    }

    // MARK: - Actions

    private func createTask() {
        let description = newTaskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else { return }
        guard !isCreatingTask else { return }

        isCreatingTask = true

        Task {
            let task = TaskRecord(taskDescription: description)
            modelContext.insert(task)

            // Try AI breakdown if available
            if breakdownService.isAvailable {
                do {
                    let breakdown = try await breakdownService.breakdownTask(description)

                    // Update task with AI results
                    task.category = breakdown.category
                    task.complexity = breakdown.complexity
                    task.stepCount = breakdown.steps.count

                    // Create subtasks from steps
                    for (index, step) in breakdown.steps.enumerated() {
                        let subtask = SubtaskRecord(
                            title: step.description,
                            estimatedMinutes: step.estimatedMinutes,
                            difficulty: step.difficulty,
                            orderIndex: index
                        )
                        subtask.task = task
                        task.subtasks.append(subtask)
                    }

                    // Get blended time estimate
                    let estimate = estimationService.estimate(for: breakdown)
                    task.predictedDuration = estimate.duration

                } catch {
                    // Task still created, just without AI breakdown
                    print("AI breakdown failed: \(error.localizedDescription)")
                }
            }

            newTaskDescription = ""
            isCreatingTask = false
            showingAddTask = false
        }
    }

    private func selectTask(_ task: TaskRecord) {
        // TODO: Navigate to task detail/timer view
    }

    private func completeTask(_ task: TaskRecord) {
        withAnimation {
            task.isComplete = true
            task.completedAt = Date()
        }
    }

    private func uncompleteTask(_ task: TaskRecord) {
        withAnimation {
            task.isComplete = false
            task.completedAt = nil
        }
    }

    private func deleteTask(_ task: TaskRecord) {
        withAnimation {
            modelContext.delete(task)
        }
    }
}

#if DEBUG
#Preview("Task List") {
    TaskListView()
        .modelContainer({
            let container = try! ModelContainer(
                for: TaskRecord.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let context = container.mainContext

            let task1 = TaskRecord(taskDescription: "Clean the kitchen")
            task1.predictedDuration = 1800
            task1.category = .cleaning
            context.insert(task1)

            let task2 = TaskRecord(taskDescription: "Reply to emails")
            task2.predictedDuration = 900
            task2.category = .work
            context.insert(task2)

            let task3 = TaskRecord(taskDescription: "Go for a walk")
            task3.predictedDuration = 1200
            task3.category = .selfCare
            context.insert(task3)

            let completed = TaskRecord(taskDescription: "Make breakfast")
            completed.isComplete = true
            completed.completedAt = Date()
            completed.predictedDuration = 600
            context.insert(completed)

            return container
        }())
}

#Preview("Empty State") {
    TaskListView()
        .modelContainer(for: TaskRecord.self, inMemory: true)
}

#Preview("No AI") {
    TaskListView(forceAIDisabled: true)
        .modelContainer(for: TaskRecord.self, inMemory: true)
}
#endif
