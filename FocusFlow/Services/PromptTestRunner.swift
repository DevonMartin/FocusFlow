//
//  PromptTestRunner.swift
//  FocusFlow
//
//  In-app prompt testing service for evaluating different instruction styles.
//  Runs validation and breakdown tests against Foundation Models on device.
//

import Foundation
import FoundationModels

// MARK: - Test Configuration

/// A named instruction style to test
struct InstructionStyle: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let instructions: String
}

/// Test input with expected result
struct ValidationTestCase: Identifiable, Sendable {
    let id = UUID()
    let input: String
    let expectedValid: Bool
}

/// Result of a single validation test
struct ValidationTestResult: Identifiable, Sendable {
    let id = UUID()
    let input: String
    let expectedValid: Bool
    let actualValid: Bool
    let reasoning: String

    var passed: Bool { expectedValid == actualValid }
}

/// Results for one instruction style
struct InstructionTestResults: Identifiable, Sendable {
    let id = UUID()
    let styleName: String
    let instructions: String
    let validationResults: [ValidationTestResult]
    let breakdownResults: [BreakdownTestResult]

    var validationPassRate: Double {
        guard !validationResults.isEmpty else { return 0 }
        let passed = validationResults.filter(\.passed).count
        return Double(passed) / Double(validationResults.count)
    }
}

/// Result of a breakdown test
struct BreakdownTestResult: Identifiable, Sendable {
    let id = UUID()
    let input: String
    let taskName: String
    let steps: [StepResult]
    let complexity: Int
    let category: String
    let totalMinutes: Int
}

struct StepResult: Identifiable, Sendable {
    let id = UUID()
    let description: String
    let estimatedMinutes: Int
    let difficulty: String
}

// MARK: - Predefined Test Data

enum PromptTestData {

    // MARK: Validation Test Cases

    static let validationTests: [ValidationTestCase] = [
        // VALID - Full phrases
        ValidationTestCase(input: "clean the kitchen", expectedValid: true),
        ValidationTestCase(input: "call mom", expectedValid: true),
        ValidationTestCase(input: "write report", expectedValid: true),
        ValidationTestCase(input: "go for a walk", expectedValid: true),
        ValidationTestCase(input: "buy groceries", expectedValid: true),
        ValidationTestCase(input: "send email to boss", expectedValid: true),
        ValidationTestCase(input: "schedule dentist appointment", expectedValid: true),
        ValidationTestCase(input: "pay rent", expectedValid: true),
        ValidationTestCase(input: "pick up dry cleaning", expectedValid: true),
        ValidationTestCase(input: "water the plants", expectedValid: true),
        ValidationTestCase(input: "take out trash", expectedValid: true),
        ValidationTestCase(input: "finish homework", expectedValid: true),
        ValidationTestCase(input: "respond to texts", expectedValid: true),
        ValidationTestCase(input: "meal prep for the week", expectedValid: true),

        // VALID - Single words (clear activities)
        ValidationTestCase(input: "laundry", expectedValid: true),
        ValidationTestCase(input: "gym", expectedValid: true),
        ValidationTestCase(input: "groceries", expectedValid: true),
        ValidationTestCase(input: "dishes", expectedValid: true),
        ValidationTestCase(input: "vacuum", expectedValid: true),
        ValidationTestCase(input: "meditate", expectedValid: true),
        ValidationTestCase(input: "stretch", expectedValid: true),
        ValidationTestCase(input: "shower", expectedValid: true),

        // VALID - Casual/shorthand
        ValidationTestCase(input: "call dr", expectedValid: true),
        ValidationTestCase(input: "fix bike", expectedValid: true),
        ValidationTestCase(input: "return package", expectedValid: true),
        ValidationTestCase(input: "check mail", expectedValid: true),

        // INVALID - Keyboard mashing / gibberish
        ValidationTestCase(input: "asdfghjkl", expectedValid: false),
        ValidationTestCase(input: "qwerty", expectedValid: false),
        ValidationTestCase(input: "jkl;", expectedValid: false),
        ValidationTestCase(input: "zxcvbnm", expectedValid: false),
        ValidationTestCase(input: "qwerty uiop", expectedValid: false),
        ValidationTestCase(input: "asdf jkl", expectedValid: false),
        ValidationTestCase(input: "fghfgh", expectedValid: false),
        ValidationTestCase(input: "hhhhhh", expectedValid: false),

        // INVALID - Random short strings
        ValidationTestCase(input: "xyz", expectedValid: false),
        ValidationTestCase(input: "abc", expectedValid: false),
        ValidationTestCase(input: "aaa bbb ccc", expectedValid: false),
        ValidationTestCase(input: "zzz", expectedValid: false),
        ValidationTestCase(input: "xxx", expectedValid: false),

        // INVALID - Too short/meaningless
        ValidationTestCase(input: "a", expectedValid: false),
        ValidationTestCase(input: "aa", expectedValid: false),
        ValidationTestCase(input: "ab cd", expectedValid: false),

        // INVALID - Nonsense that looks like words
        ValidationTestCase(input: "flurb the gnarp", expectedValid: false),
        ValidationTestCase(input: "blorg", expectedValid: false),
        ValidationTestCase(input: "snorf wibble", expectedValid: false),

        // INVALID - Names (not actionable)
        ValidationTestCase(input: "John", expectedValid: false),
        ValidationTestCase(input: "Sarah Miller", expectedValid: false),
        ValidationTestCase(input: "Dr. Smith", expectedValid: false),
        ValidationTestCase(input: "my friend Mike", expectedValid: false),

        // INVALID - Places (not actionable)
        ValidationTestCase(input: "California", expectedValid: false),
        ValidationTestCase(input: "New York City", expectedValid: false),
        ValidationTestCase(input: "the coffee shop", expectedValid: false),
        ValidationTestCase(input: "Target", expectedValid: false),
        ValidationTestCase(input: "home", expectedValid: false),

        // INVALID - Objects/nouns without action
        ValidationTestCase(input: "laptop", expectedValid: false),
        ValidationTestCase(input: "blue shirt", expectedValid: false),
        ValidationTestCase(input: "my car", expectedValid: false),
        ValidationTestCase(input: "birthday cake", expectedValid: false),

        // INVALID - Feelings/states (not actionable)
        ValidationTestCase(input: "tired", expectedValid: false),
        ValidationTestCase(input: "happy", expectedValid: false),
        ValidationTestCase(input: "stressed about work", expectedValid: false),

        // INVALID - Questions/statements
        ValidationTestCase(input: "what time is it", expectedValid: false),
        ValidationTestCase(input: "I don't know", expectedValid: false),
        ValidationTestCase(input: "maybe later", expectedValid: false),
    ]

    // MARK: Breakdown Test Inputs

    static let breakdownInputs: [String] = [
        "clean the kitchen",
        "write a thank you email",
        "organize my desk",
        "prepare for job interview",
        "do laundry",
        "meal prep for the week",
        "file my taxes",
        "pack for a trip",
    ]

    // MARK: Validation Instruction Styles

    static let validationStyles: [InstructionStyle] = [
        InstructionStyle(
            name: "A: Minimal",
            instructions: "Classify user input as valid or invalid tasks."
        ),
        InstructionStyle(
            name: "B: With Examples",
            instructions: """
                Classify the input as a valid or invalid task.

                Examples of VALID tasks:
                - "clean the kitchen"
                - "call mom"
                - "write report"
                - "laundry"

                Examples of INVALID inputs:
                - "asdfghjkl" (random letters)
                - "xyz" (too short, no meaning)
                - "aaa bbb ccc" (repeated nonsense)
                """
        ),
        InstructionStyle(
            name: "C: DO NOT Commands",
            instructions: """
                Classify the input as a valid or invalid task.

                Valid: A clear action someone can do (clean kitchen, call mom, write report).
                Invalid: Random letters, gibberish, or meaningless text.

                DO NOT interpret random letters as words.
                DO NOT assume gibberish has hidden meaning.
                DO NOT classify nonsense strings as valid tasks.
                """
        ),
    ]

    // MARK: Breakdown Instruction Styles

    static let breakdownStyles: [InstructionStyle] = [
        InstructionStyle(
            name: "A: Minimal",
            instructions: "Break down tasks into actionable steps."
        ),
        InstructionStyle(
            name: "B: Detailed Role",
            instructions: """
                You are a supportive task assistant for people who work best with small, clear steps.

                Guidelines for breaking down tasks:
                - Each step should be ONE clear action (not multiple actions combined)
                - Steps should be in logical order
                - Prefer short steps (5-15 minutes each)
                - Include "getting started" steps (gather supplies, open app)
                - Use encouraging, specific language
                """
        ),
        InstructionStyle(
            name: "C: With Example",
            instructions: """
                Break down tasks into small, concrete action steps.

                Example for "do laundry":
                1. Gather dirty clothes from hamper (2 min)
                2. Sort clothes by color (3 min)
                3. Load washing machine with first batch (2 min)
                4. Add detergent and start cycle (1 min)
                5. Set timer to switch to dryer (1 min)

                Keep steps short (5-15 min each). Use clear action verbs.
                """
        ),
        InstructionStyle(
            name: "D: ADHD-Optimized",
            instructions: """
                You help people with ADHD break tasks into tiny, doable steps.

                ADHD-friendly guidelines:
                - Start with the EASIEST step to build momentum
                - Each step should take 5-15 minutes maximum
                - Be very specific (not "clean" but "wipe down counters")
                - Include transition steps ("put on music", "gather supplies")
                - Never combine multiple actions into one step

                DO NOT create steps longer than 20 minutes.
                DO NOT use vague language like "finish up" or "do the rest".
                """
        ),
    ]
}

// MARK: - Test Runner

@MainActor
@Observable
final class PromptTestRunner {

    var isRunning = false
    var currentPhase = ""
    var progress: Double = 0
    var results: [InstructionTestResults] = []
    var error: String?

    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// Run all tests for all instruction styles
    func runAllTests() async {
        guard isAvailable else {
            error = "Foundation Models not available on this device"
            return
        }

        isRunning = true
        error = nil
        results = []

        let totalStyles = PromptTestData.validationStyles.count + PromptTestData.breakdownStyles.count
        var completedStyles = 0

        // Run validation tests for each style
        for style in PromptTestData.validationStyles {
            currentPhase = "Validation: \(style.name)"

            let validationResults = await runValidationTests(style: style)

            let result = InstructionTestResults(
                styleName: style.name,
                instructions: style.instructions,
                validationResults: validationResults,
                breakdownResults: []
            )
            results.append(result)

            completedStyles += 1
            progress = Double(completedStyles) / Double(totalStyles)
        }

        // Run breakdown tests for each style
        for style in PromptTestData.breakdownStyles {
            currentPhase = "Breakdown: \(style.name)"

            let breakdownResults = await runBreakdownTests(style: style)

            let result = InstructionTestResults(
                styleName: style.name,
                instructions: style.instructions,
                validationResults: [],
                breakdownResults: breakdownResults
            )
            results.append(result)

            completedStyles += 1
            progress = Double(completedStyles) / Double(totalStyles)
        }

        currentPhase = "Complete"
        isRunning = false
    }

    /// Run validation tests for a single instruction style
    private func runValidationTests(style: InstructionStyle) async -> [ValidationTestResult] {
        var results: [ValidationTestResult] = []

        for testCase in PromptTestData.validationTests {
            let session = LanguageModelSession { style.instructions }

            do {
                let response = try await session.respond(
                    to: "Classify: \(testCase.input)",
                    generating: PromptCheck.self
                )

                let result = ValidationTestResult(
                    input: testCase.input,
                    expectedValid: testCase.expectedValid,
                    actualValid: response.content.validity == .valid,
                    reasoning: response.content.reasoning
                )
                results.append(result)

            } catch {
                // Record as failed with error
                let result = ValidationTestResult(
                    input: testCase.input,
                    expectedValid: testCase.expectedValid,
                    actualValid: !testCase.expectedValid, // Opposite = fail
                    reasoning: "Error: \(error.localizedDescription)"
                )
                results.append(result)
            }
        }

        return results
    }

    /// Run breakdown tests for a single instruction style
    private func runBreakdownTests(style: InstructionStyle) async -> [BreakdownTestResult] {
        var results: [BreakdownTestResult] = []

        for input in PromptTestData.breakdownInputs {
            let session = LanguageModelSession { style.instructions }

            do {
                let response = try await session.respond(
                    to: "Break down this task: \(input)",
                    generating: TaskBreakdown.self
                )

                let breakdown = response.content
                let result = BreakdownTestResult(
                    input: input,
                    taskName: breakdown.taskName,
                    steps: breakdown.steps.map { step in
                        StepResult(
                            description: step.description,
                            estimatedMinutes: step.estimatedMinutes,
                            difficulty: step.difficulty.rawValue
                        )
                    },
                    complexity: breakdown.complexity,
                    category: breakdown.category.rawValue,
                    totalMinutes: breakdown.totalMinutes
                )
                results.append(result)

            } catch {
                // Record empty result with error indication
                let result = BreakdownTestResult(
                    input: input,
                    taskName: "Error: \(error.localizedDescription)",
                    steps: [],
                    complexity: 0,
                    category: "error",
                    totalMinutes: 0
                )
                results.append(result)
            }
        }

        return results
    }
}
