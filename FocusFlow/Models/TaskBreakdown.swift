//
//  TaskBreakdown.swift
//  FocusFlow
//
//  Generable types for Foundation Models task breakdown output.
//

import Foundation
import FoundationModels

// MARK: - Enums

@Generable
enum TaskCategory: String, Codable, CaseIterable, Sendable {
    case cleaning
    case cooking
    case organizing
    case errands
    case work
    case selfCare = "self-care"
    case admin
    case creative
    case social
    case other
}

@Generable
enum Difficulty: String, Codable, CaseIterable, Sendable {
    case easy
    case medium
    case hard
}

// MARK: - Task Breakdown

@Generable
struct TaskBreakdown {
    @Guide(description: "The main task being broken down")
    let taskName: String

    @Guide(description: "Individual action steps, ordered from first to last")
    let steps: [TaskStep]

    @Guide(description: "Total estimated minutes for average person", .range(1...480))
    let totalMinutes: Int

    @Guide(description: "Overall complexity 1-10", .range(1...10))
    let complexity: Int

    let category: TaskCategory
}

@Generable
struct TaskStep {
    @Guide(description: "Clear, actionable step description")
    let description: String

    @Guide(description: "Estimated minutes for this step", .range(1...120))
    let estimatedMinutes: Int

    let difficulty: Difficulty
}
