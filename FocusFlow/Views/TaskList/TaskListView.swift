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
    @State private var showingLegibilityAlert = false
    @State private var pendingTaskDescription = ""

    @State private var breakdownService = TaskBreakdownService()
    private var estimationService = TimeEstimationService(
        estimator: EWMAEstimator()
    )

    #if DEBUG
    @State private var showingPromptTesting = false
    #endif

    @State private var showingAIUnavailableAlert = false
    @State private var bannerDismissedThisSession = false
    @State private var showingBreakdownFailedAlert = false
    @AppStorage("hasSeenAIUnavailableAlert") private var hasSeenAIUnavailableAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Dismissible banner (shown each session until dismissed)
                    if !breakdownService.isAvailable && !bannerDismissedThisSession {
                        aiBanner
                    }

                    if tasks.isEmpty {
                        emptyState
                    } else {
                        taskList
                    }
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .navigation) {
                    Button {
                        showingPromptTesting = true
                    } label: {
                        Image(systemName: "testtube.2")
                            .font(.title3)
                            .foregroundStyle(DesignSystem.Colors.secondary)
                    }
                }
                #endif

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
            #if DEBUG
            .sheet(isPresented: $showingPromptTesting) {
                PromptTestingView()
            }
            #endif
            .sheet(isPresented: $showingAddTask) {
                addTaskSheet
            }
            .onAppear {
                // One-time alert (only shown once ever, unless DEBUG)
                if !breakdownService.isAvailable && !hasSeenAIUnavailableAlert {
                    showingAIUnavailableAlert = true
                    #if !DEBUG
                    hasSeenAIUnavailableAlert = true
                    #endif
                }
            }
            .alert(aiAlertTitle, isPresented: $showingAIUnavailableAlert) {
                Button("OK") { }
            } message: {
                Text(aiAlertMessage)
            }
            .alert(DesignSystem.Language.breakdownFailedTitle, isPresented: $showingBreakdownFailedAlert) {
                Button("OK") { }
            } message: {
                Text(DesignSystem.Language.breakdownFailedMessage)
            }
        }
    }

    // MARK: - AI Availability

    private var aiBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(DesignSystem.Colors.neutral)

            Text(aiBannerMessage)
                .font(DesignSystem.Typography.callout)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Spacer()

            Button {
                withAnimation {
                    bannerDismissedThisSession = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(DesignSystem.Colors.surface)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var aiBannerMessage: String {
        switch breakdownService.unavailabilityReason {
        case .deviceNotSupported:
            return DesignSystem.Language.aiBannerDeviceNotSupported
        case .appleIntelligenceNotEnabled:
            return DesignSystem.Language.aiBannerIntelligenceOff
        case .modelNotReady:
            return DesignSystem.Language.aiBannerModelNotReady
        case .unknown, .none:
            return DesignSystem.Language.aiBannerUnknown
        }
    }

    private var aiAlertTitle: String {
        switch breakdownService.unavailabilityReason {
        case .modelNotReady:
            return DesignSystem.Language.aiAlertTitleSettingUp
        case .deviceNotSupported, .appleIntelligenceNotEnabled, .unknown, .none:
            return DesignSystem.Language.aiAlertTitleUnavailable
        }
    }

    private var aiAlertMessage: String {
        switch breakdownService.unavailabilityReason {
        case .deviceNotSupported:
            return DesignSystem.Language.aiAlertDeviceNotSupported
        case .appleIntelligenceNotEnabled:
            return DesignSystem.Language.aiAlertIntelligenceOff
        case .modelNotReady:
            return DesignSystem.Language.aiAlertModelNotReady
        case .unknown, .none:
            return DesignSystem.Language.aiAlertUnknown
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
                    .disabled(isCreatingTask || breakdownService.isResponding)

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
                    .disabled(newTaskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || breakdownService.isResponding)
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
        .alert("Unclear Task", isPresented: $showingLegibilityAlert) {
            Button("Add Anyway") {
                createTaskWithoutBreakdown()
            }
            Button("Rephrase", role: .cancel) {
                // Sheet stays open for user to edit
            }
        } message: {
            Text("This doesn't look like an actionable task. Would you like to rephrase it, or add it without AI breakdown?")
        }
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
            // Check if the prompt looks like an actionable task
            if breakdownService.isAvailable {
                let check = (try? await breakdownService.checkPrompt(description)) ?? PromptCheck(reasoning: "", validity: .valid)

                if !check.isActionable {
                    // Show alert asking user to rephrase or proceed without breakdown
                    pendingTaskDescription = description
                    isCreatingTask = false
                    showingLegibilityAlert = true
                    return
                }
            }

            await createTaskWithBreakdown(description: description)
        }
    }

    private func createTaskWithBreakdown(description: String) async {
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
                showingBreakdownFailedAlert = true
            }
        }

        newTaskDescription = ""
        isCreatingTask = false
        showingAddTask = false
    }

    private func createTaskWithoutBreakdown() {
        let task = TaskRecord(taskDescription: pendingTaskDescription)
        modelContext.insert(task)

        newTaskDescription = ""
        pendingTaskDescription = ""
        showingAddTask = false
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
	// Note: To test with AI disabled, set breakdownService.forceDisabled = true
	// in the service's DEBUG block
}
#endif
