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

/// Service for breaking down tasks using Foundation Models.
/// Creates fresh sessions per request to avoid context bloat.
/// Main actor-isolated because SystemLanguageModel.default requires it.
@MainActor
@Observable
final class TaskBreakdownService {

    /// Current active session (for isResponding check)
    private var activeSession: LanguageModelSession?

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

    /// True if a session is currently generating a response
    var isResponding: Bool {
        activeSession?.isResponding ?? false
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

    /// Checks if user input looks like an actionable task
    /// - Parameter text: The user's input text
    /// - Returns: PromptCheck with reasoning and validity
    func checkPrompt(_ text: String) async throws -> PromptCheck {
        guard isAvailable else {
            // If AI unavailable, assume valid and let user proceed
            return PromptCheck(reasoning: "AI unavailable", validity: .valid)
        }

        let session = LanguageModelSession {
            """
            Classify the input as a valid or invalid task.

            Valid: A clear action someone can do (clean kitchen, call mom, write report).
            Invalid: Random letters, gibberish, or meaningless text.

            DO NOT interpret random letters as words.
            DO NOT assume gibberish has hidden meaning.
            DO NOT classify nonsense strings as valid tasks.
            """
        }
        activeSession = session
        defer { activeSession = nil }

        do {
            let response = try await session.respond(
                to: "Classify: \(text)",
                generating: PromptCheck.self
            )
            return response.content
        } catch {
            // On error, assume valid and proceed
            return PromptCheck(reasoning: "Check failed", validity: .valid)
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
            You are a supportive task assistant for people who work best with small, clear steps.

            Guidelines for breaking down tasks:
            - Each step should be ONE clear action (not multiple actions combined)
            - Steps should be in logical order
            - Prefer short steps (5-15 minutes each)
            - Include "getting started" steps (gather supplies, open app)
            - Use encouraging, specific language
            - \(pace.promptFragment)
            """

        let session = LanguageModelSession { systemPrompt }
        activeSession = session
        defer { activeSession = nil }

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
