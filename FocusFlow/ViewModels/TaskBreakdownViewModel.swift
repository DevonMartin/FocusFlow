//
//  TaskBreakdownViewModel.swift
//  FocusFlow
//
//  Observable view model for task breakdown UI state.
//

import Foundation

@MainActor
@Observable
final class TaskBreakdownViewModel {
    private(set) var isProcessing = false
    private(set) var lastError: Error?
    private(set) var lastBreakdown: TaskBreakdown?

    var userPace: UserPace = .average

    private let service: TaskBreakdownService

    var isAvailable: Bool {
        service.isAvailable
    }

    var unavailabilityReason: AIUnavailabilityReason? {
        service.unavailabilityReason
    }

    /// Creates a view model with an injected service (for testing)
    init(service: TaskBreakdownService) {
        self.service = service
    }

    /// Creates a view model with the default service (for production use)
    convenience init() {
        self.init(service: TaskBreakdownService())
    }

    /// Breaks down a task and updates observable state
    func breakdownTask(_ description: String) async throws -> TaskBreakdown {
        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        do {
            let breakdown = try await service.breakdownTask(description, pace: userPace)
            lastBreakdown = breakdown
            return breakdown
        } catch {
            lastError = error
            throw error
        }
    }

    func clearError() {
        lastError = nil
    }
}
