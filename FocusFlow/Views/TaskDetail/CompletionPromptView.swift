//
//  CompletionPromptView.swift
//  FocusFlow
//
//  Prompts user to confirm or estimate task duration on completion.
//

import SwiftUI

struct CompletionPromptView: View {
    @Bindable var task: TaskRecord
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingRanges = false
    @State private var customMinutes: String = ""
    @State private var selectedOption: DurationOption?
    @FocusState private var isCustomFieldFocused: Bool

    private enum DurationOption: Equatable {
        case preset(Int)  // minutes
        case custom
        case skip
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 64))
                        .foregroundStyle(DesignSystem.Colors.gentle)
                        .padding(.top, 32)

                    // Message
                    Text(DesignSystem.Language.niceWork)
                        .font(DesignSystem.Typography.title)
                        .foregroundStyle(DesignSystem.Colors.text)

                    if showingRanges {
                        rangeSelection
                    } else if hasTrackedTime {
                        elapsedConfirmation
                    } else {
                        // No start time - go straight to ranges
                        rangeSelection
                    }
                }
                .padding()
            }
            .background(DesignSystem.Colors.background)
            .onTapGesture {
                isCustomFieldFocused = false
            }
            .navigationTitle("Complete Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Elapsed Time Confirmation

    private var hasTrackedTime: Bool {
        task.startTime != nil || task.accumulatedDuration != nil
    }

    private var elapsedConfirmation: some View {
        VStack(spacing: 20) {
            Text(elapsedTimeQuestion)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                GentleButton("Yes", style: .primary) {
                    confirmElapsedTime()
                }
                .frame(maxWidth: .infinity)

                GentleButton("No", style: .subtle) {
                    withAnimation {
                        showingRanges = true
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var elapsedTimeQuestion: String {
        let elapsed = task.elapsedDuration
        let totalMinutes = Int(elapsed / 60)
        let formatted: String
        if totalMinutes > 0 {
            formatted = DesignSystem.Language.formatDuration(minutes: totalMinutes)
        } else {
            formatted = "less than a minute"
        }
        return "You worked on this for \(formatted) \u{2014} is that right?"
    }

    private func confirmElapsedTime() {
        task.complete()
        recordToEWMA()
        onComplete()
        dismiss()
    }

    private func recordToEWMA() {
        guard let actualDuration = task.actualDuration,
              let category = task.category,
              let originalEstimate = task.predictedDuration else {
            return
        }

        TimeEstimationService.shared.recordCompletion(
            actualDuration: actualDuration,
            category: category,
            originalEstimate: originalEstimate
        )
    }

    // MARK: - Range Selection

    private var rangeSelection: some View {
        VStack(spacing: 16) {
            Text("How long did this take?")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            // 2x4 grid: 6 presets + custom input + skip
            let ranges = durationRanges
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Preset duration buttons
                ForEach(ranges, id: \.minutes) { range in
                    optionButton(
                        label: range.label,
                        isSelected: selectedOption == .preset(range.minutes),
                        textColor: DesignSystem.Colors.text
                    ) {
                        selectedOption = .preset(range.minutes)
                        isCustomFieldFocused = false
                    }
                }

                // Custom time input
                HStack(spacing: 8) {
                    TextField("", text: $customMinutes, prompt: Text("Other").foregroundStyle(DesignSystem.Colors.textSecondary))
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.text)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .focused($isCustomFieldFocused)
                        .frame(maxWidth: .infinity)
                        .onChange(of: customMinutes) {
                            if customMinutes.isEmpty {
                                // Clearing the field deselects custom
                                if selectedOption == .custom {
                                    selectedOption = nil
                                }
                            } else {
                                selectedOption = .custom
                            }
                        }
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    isCustomFieldFocused = false
                                }
                                .fontWeight(.semibold)
                            }
                        }
                        .onChange(of: isCustomFieldFocused) { _, focused in
                            if focused && !customMinutes.isEmpty {
                                // Focusing with existing input selects custom
                                selectedOption = .custom
                            }
                        }

                    if !customMinutes.isEmpty {
                        Text("min")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            selectedOption == .custom ? DesignSystem.Colors.primary : Color.clear,
                            lineWidth: 2
                        )
                )
                .onTapGesture {
                    selectedOption = .custom
                    isCustomFieldFocused = true
                }

                // Skip option
                optionButton(
                    label: "I don't know",
                    isSelected: selectedOption == .skip,
                    textColor: DesignSystem.Colors.textSecondary
                ) {
                    selectedOption = .skip
                    isCustomFieldFocused = false
                }
            }

            // Submit button (always visible, enabled when valid selection)
            GentleButton("Submit", style: .primary) {
                submitSelection()
            }
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1.0 : 0.5)
        }
    }

    private func optionButton(label: String, isSelected: Bool, textColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isSelected ? DesignSystem.Colors.primary : Color.clear,
                            lineWidth: 2
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var canSubmit: Bool {
        switch selectedOption {
        case .preset:
            return true
        case .custom:
            guard let minutes = Int(customMinutes) else { return false }
            return minutes > 0
        case .skip:
            return true
        case .none:
            return false
        }
    }

    private func submitSelection() {
        switch selectedOption {
        case .preset(let minutes):
            selectDuration(minutes)
        case .custom:
            guard let minutes = Int(customMinutes), minutes > 0 else { return }
            selectDuration(minutes)
        case .skip:
            skipDuration()
        case .none:
            break
        }
    }

    private struct DurationRange {
        let label: String
        let minutes: Int
    }

    private var durationRanges: [DurationRange] {
        // Generate 6 ranges based on predicted duration (for 2x3 grid)
        let predictedMinutes = Int((task.predictedDuration ?? 1800) / 60)

        // Create ranges around the prediction
        let ranges: [Int]
        if predictedMinutes <= 15 {
            ranges = [5, 10, 15, 20, 30, 45]
        } else if predictedMinutes <= 30 {
            ranges = [10, 15, 20, 30, 45, 60]
        } else if predictedMinutes <= 60 {
            ranges = [15, 30, 45, 60, 90, 120]
        } else if predictedMinutes <= 120 {
            ranges = [30, 45, 60, 90, 120, 180]
        } else {
            ranges = [60, 90, 120, 180, 240, 300]
        }

        return ranges.map { minutes in
            DurationRange(label: formatRangeLabel(minutes), minutes: minutes)
        }
    }

    private func formatRangeLabel(_ minutes: Int) -> String {
        DesignSystem.Language.formatDuration(minutes: minutes)
    }

    private func selectDuration(_ minutes: Int) {
        let duration = TimeInterval(minutes * 60)
        task.complete(withDuration: duration)
        recordToEWMA()
        onComplete()
        dismiss()
    }

    private func skipDuration() {
        // Complete without recording duration for EWMA
        task.isComplete = true
        task.completedAt = Date()
        task.endTime = Date()
        // Don't set actualDuration - skip EWMA training
        onComplete()
        dismiss()
    }
}

#if DEBUG
import SwiftData

#Preview("With Elapsed Time") {
    let container = try! ModelContainer(
        for: TaskRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let task = TaskRecord(taskDescription: "Clean the kitchen")
    task.predictedDuration = 1800
    task.accumulatedDuration = 1520 // ~25 minutes
    context.insert(task)

    return CompletionPromptView(task: task) {}
        .modelContainer(container)
}

#Preview("Without Start Time") {
    let container = try! ModelContainer(
        for: TaskRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let task = TaskRecord(taskDescription: "Quick task")
    task.predictedDuration = 600
    context.insert(task)

    return CompletionPromptView(task: task) {}
        .modelContainer(container)
}
#endif
