//
//  TaskBreakdownService.swift
//  FocusFlow
//
//  Breaks down user tasks into manageable subtasks using Foundation Models.
//

import Foundation
import FoundationModels

/// User's self-reported pace for time estimates
enum UserPace: String, Codable, CaseIterable, Sendable {
    case slower
    case average
    case faster

    var displayName: String {
        switch self {
        case .slower: return "I like extra buffer time"
        case .average: return "About average"
        case .faster: return "I work pretty quickly"
        }
    }

    var promptFragment: String {
        switch self {
        case .slower:
            return "Time estimates should be generous - this person prefers extra buffer time"
        case .average:
            return "Time estimates should be realistic for an average person"
        case .faster:
            return "Time estimates can be tighter - this person works quickly"
        }
    }
}

/// Pure service for breaking down tasks using Foundation Models.
/// Contains no UI state - use TaskBreakdownViewModel for observable state.
/// Main actor-isolated because SystemLanguageModel.default requires it.
@MainActor
struct TaskBreakdownService {

    #if DEBUG
    /// Set to true to simulate AI being unavailable (for testing fallback UI)
    var forceDisabled = false
    #endif

    var isAvailable: Bool {
        #if DEBUG
        if forceDisabled { return false }
        #endif
        return SystemLanguageModel.default.isAvailable
    }

    var unavailabilityReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support on-device AI. iPhone 15 Pro or newer required."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Please enable Apple Intelligence in Settings to use AI features."
        case .unavailable(.modelNotReady):
            return "AI model is still downloading. Please try again in a few minutes."
        @unknown default:
            return "AI features are currently unavailable."
        }
    }

    /// Breaks down a task into manageable steps
    /// - Parameters:
    ///   - description: The task to break down
    ///   - pace: User's preferred pace for time estimates
    /// - Returns: A TaskBreakdown with steps, complexity, and category
    func breakdownTask(_ description: String, pace: UserPace = .average) async throws -> TaskBreakdown {
        guard isAvailable else {
            throw TaskBreakdownError.notAvailable(unavailabilityReason ?? "Unknown error")
        }

        let systemPrompt = """
            You are a supportive task assistant. Your job is to break down tasks into small, concrete, actionable steps.

            Guidelines:
            - Each step should be a single, clear action (not multiple actions)
            - Steps should be ordered logically
            - \(pace.promptFragment)
            - Use encouraging, clear language
            - Prefer shorter steps (5-15 minutes) over longer ones
            - Include "getting started" steps when relevant (gather materials, open app, etc.)
            """

        let session = LanguageModelSession { systemPrompt }

        do {
            let response = try await session.respond(
                to: "Break down this task into manageable steps: \(description)",
                generating: TaskBreakdown.self
            )
            return response.content
        } catch {
            throw TaskBreakdownError.generationFailed
        }
    }
}

enum TaskBreakdownError: LocalizedError {
    case notAvailable(String)
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable(let reason):
            return reason
        case .generationFailed:
            return "Couldn't break down that task. Try rephrasing it?"
        }
    }
}
