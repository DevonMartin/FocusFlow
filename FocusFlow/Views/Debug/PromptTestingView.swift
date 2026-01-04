//
//  PromptTestingView.swift
//  FocusFlow
//
//  Debug view for testing Foundation Models prompts on device.
//  Displays validation and breakdown results grouped by instruction style.
//

import SwiftUI

struct PromptTestingView: View {
    @State private var runner = PromptTestRunner()

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                if runner.results.isEmpty && !runner.isRunning {
                    startView
                } else if runner.isRunning {
                    progressView
                } else {
                    resultsList
                }
            }
            .navigationTitle("Prompt Testing")
            .toolbar {
                if !runner.isRunning && !runner.results.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Re-run") {
                            Task { await runner.runAllTests() }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Start View

    private var startView: some View {
        VStack(spacing: 24) {
            Image(systemName: "testtube.2")
                .font(.system(size: 64))
                .foregroundStyle(DesignSystem.Colors.secondary)

            Text("Prompt Testing Lab")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.text)

            Text("Test different instruction styles for validation and task breakdown. Results run on-device using Foundation Models.")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if runner.isAvailable {
                GentleButton("Run All Tests", icon: "play.fill", style: .primary) {
                    Task { await runner.runAllTests() }
                }
                .frame(maxWidth: 200)
            } else {
                Text("Foundation Models not available")
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(.orange)
            }

            if let error = runner.error {
                Text(error)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }

    // MARK: - Progress View

    private var progressView: some View {
        VStack(spacing: 20) {
            ProgressView(value: runner.progress)
                .progressViewStyle(.linear)
                .frame(maxWidth: 300)

            Text(runner.currentPhase)
                .font(DesignSystem.Typography.callout)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Text("\(Int(runner.progress * 100))%")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.text)
        }
        .padding()
    }

    // MARK: - Results List

    private var resultsList: some View {
        List {
            // Validation Results Section
            Section {
                ForEach(runner.results.filter { !$0.validationResults.isEmpty }) { result in
                    NavigationLink {
                        ValidationResultDetailView(result: result)
                    } label: {
                        ValidationResultRow(result: result)
                    }
                }
            } header: {
                Text("VALIDATION TESTS")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            // Breakdown Results Section
            Section {
                ForEach(runner.results.filter { !$0.breakdownResults.isEmpty }) { result in
                    NavigationLink {
                        BreakdownResultDetailView(result: result)
                    } label: {
                        BreakdownResultRow(result: result)
                    }
                }
            } header: {
                Text("BREAKDOWN TESTS")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Validation Result Row

private struct ValidationResultRow: View {
    let result: InstructionTestResults

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.styleName)
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.text)

            HStack {
                let passed = result.validationResults.filter(\.passed).count
                let total = result.validationResults.count

                Text("\(passed)/\(total) passed")
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(passRateColor)

                Spacer()

                Text("\(Int(result.validationPassRate * 100))%")
                    .font(DesignSystem.Typography.callout.bold())
                    .foregroundStyle(passRateColor)
            }
        }
        .padding(.vertical, 4)
    }

    private var passRateColor: Color {
        if result.validationPassRate >= 0.9 {
            return .green
        } else if result.validationPassRate >= 0.7 {
            return .orange
        } else {
            return DesignSystem.Colors.textSecondary
        }
    }
}

// MARK: - Validation Result Detail

private struct ValidationResultDetailView: View {
    let result: InstructionTestResults

    var body: some View {
        List {
            // Instructions Section
            Section {
                Text(result.instructions)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            } header: {
                Text("INSTRUCTIONS")
            }

            // Passed Tests
            Section {
                ForEach(result.validationResults.filter(\.passed)) { test in
                    ValidationTestResultRow(test: test)
                }
            } header: {
                let count = result.validationResults.filter(\.passed).count
                Text("PASSED (\(count))")
            }

            // Failed Tests
            Section {
                ForEach(result.validationResults.filter { !$0.passed }) { test in
                    ValidationTestResultRow(test: test)
                }
            } header: {
                let count = result.validationResults.filter { !$0.passed }.count
                Text("FAILED (\(count))")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(result.styleName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ValidationTestResultRow: View {
    let test: ValidationTestResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: test.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(test.passed ? .green : .orange)

                Text("\"\(test.input)\"")
                    .font(DesignSystem.Typography.body.bold())
                    .foregroundStyle(DesignSystem.Colors.text)
            }

            HStack(spacing: 16) {
                Label("Expected: \(test.expectedValid ? "valid" : "invalid")",
                      systemImage: test.expectedValid ? "checkmark" : "xmark")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Label("Got: \(test.actualValid ? "valid" : "invalid")",
                      systemImage: test.actualValid ? "checkmark" : "xmark")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(test.passed ? .green : .orange)
            }

            Text(test.reasoning)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .italic()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Breakdown Result Row

private struct BreakdownResultRow: View {
    let result: InstructionTestResults

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.styleName)
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.text)

            Text("\(result.breakdownResults.count) tasks tested")
                .font(DesignSystem.Typography.callout)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Breakdown Result Detail

private struct BreakdownResultDetailView: View {
    let result: InstructionTestResults

    var body: some View {
        List {
            // Instructions Section
            Section {
                Text(result.instructions)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            } header: {
                Text("INSTRUCTIONS")
            }

            // Each breakdown result
            ForEach(result.breakdownResults) { breakdown in
                Section {
                    // Summary
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Task: \(breakdown.taskName)")
                                .font(DesignSystem.Typography.body.bold())
                            Text("Category: \(breakdown.category)")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(breakdown.totalMinutes) min")
                                .font(DesignSystem.Typography.headline)
                            Text("Complexity: \(breakdown.complexity)/10")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }

                    // Steps
                    ForEach(Array(breakdown.steps.enumerated()), id: \.element.id) { index, step in
                        HStack(alignment: .top) {
                            Text("\(index + 1).")
                                .font(DesignSystem.Typography.callout)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .frame(width: 24, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.description)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.text)

                                HStack {
                                    Text("\(step.estimatedMinutes) min")
                                    Text("•")
                                    Text(step.difficulty)
                                }
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                } header: {
                    Text("INPUT: \"\(breakdown.input)\"")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(result.styleName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    PromptTestingView()
}
#endif
