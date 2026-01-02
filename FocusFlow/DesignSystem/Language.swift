//
//  Language.swift
//  FocusFlow
//
//  ADHD-friendly copy — never shame, never "overdue", never guilt.
//  Same celebration regardless of timing.
//

import Foundation

extension DesignSystem {
    enum Language {
        // MARK: - Time Estimates

        /// Time estimate with uncertainty framing
        static func timeEstimate(_ minutes: Int) -> String {
            "This might take about \(minutes) minutes"
        }

        /// Time estimate with confidence source
        static func timeEstimateWithConfidence(_ minutes: Int, confidence: String) -> String {
            "About \(minutes) min (\(confidence))"
        }

        // MARK: - Status Messages (never shame)

        static let stillWorking = "Still working on it"
        static let readyWhenYouAre = "Ready when you are"
        static let takeYourTime = "Take your time"
        static let niceWork = "Nice work!"
        static let welcomeBack = "Welcome back"

        /// Instead of "You failed to complete..."
        static let stillOnYourList = "Still on your list"

        /// Instead of "0 days streak"
        static let getStarted = "Ready to get started?"

        // MARK: - Task Completion

        /// Random completion message — same celebration regardless of timing
        static var randomCompletionMessage: String {
            completionMessages.randomElement() ?? "Done!"
        }

        private static let completionMessages = [
            "Done! Nice work.",
            "That's one off your plate.",
            "Progress feels good.",
            "You did the thing!",
            "Check! What's next?"
        ]

        // MARK: - Overtime Handling

        static let overtimeMessage = "Taking longer than expected? That's okay—estimates are just guesses."

        // MARK: - Re-engagement (never guilt)

        /// Random return message for users coming back after absence
        static var randomReturnMessage: String {
            returnMessages.randomElement() ?? "Welcome back"
        }

        private static let returnMessages = [
            "Hey, welcome back!",
            "Good to see you.",
            "Ready when you are."
        ]

        // MARK: - Empty States

        static let emptyTaskList = "Ready to add your first task?"
        static let noSubtasks = "No steps yet"

        // MARK: - Confidence Levels

        static let confidenceLow = "rough guess"
        static let confidenceMedium = "based on a few similar tasks"
        static let confidenceHigh = "based on your history"

        // MARK: - AI Status

        static let aiProcessing = "Breaking this down..."
        static let aiUnavailable = "AI features aren't available right now"
    }
}
