//
//  TaskBreakdown.swift
//  FocusFlow
//
//  Generable struct for Foundation Models task breakdown output.
//

import Foundation
import FoundationModels

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

    @Guide(.anyOf([
        "cleaning", "cooking", "organizing", "errands",
        "work", "self-care", "admin", "creative", "social", "other"
    ]))
    let category: String
}

@Generable
struct TaskStep {
    @Guide(description: "Clear, actionable step description")
    let description: String

    @Guide(description: "Estimated minutes for this step", .range(1...120))
    let estimatedMinutes: Int

    @Guide(.anyOf(["easy", "medium", "hard"]))
    let difficulty: String
}
