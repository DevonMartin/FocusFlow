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
        // MARK: - Duration Formatting

        /// Formats a duration in minutes to a human-readable string.
        /// - Examples: "5 minutes", "1 hour", "2 hours", "2 hours 15 minutes"
        static func formatDuration(minutes: Int) -> String {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60

            if hours == 0 {
                return remainingMinutes == 1 ? "1 minute" : "\(remainingMinutes) minutes"
            } else if remainingMinutes == 0 {
                return hours == 1 ? "1 hour" : "\(hours) hours"
            } else {
                let hourPart = hours == 1 ? "1 hour" : "\(hours) hours"
                let minutePart = remainingMinutes == 1 ? "1 minute" : "\(remainingMinutes) minutes"
                return "\(hourPart) \(minutePart)"
            }
        }

        /// Formats a TimeInterval (seconds) to a human-readable string.
        static func formatDuration(seconds: TimeInterval) -> String {
            formatDuration(minutes: Int(seconds / 60))
        }

        // MARK: - Time Estimates

        /// Time estimate for task rows and subtasks
        /// - Examples: "Might take ~5 minutes", "Might take ~1 hour"
        static func timeEstimate(_ minutes: Int) -> String {
            "Might take ~\(formatDuration(minutes: minutes))"
        }

        /// Time estimate with confidence source (for detail views)
        static func timeEstimateWithConfidence(_ minutes: Int, confidence: String) -> String {
            "~\(formatDuration(minutes: minutes)) (\(confidence))"
        }

        // MARK: - Completed Task Duration

        /// Duration display for completed tasks (focuses on accomplishment)
        /// - Examples: "Finished in 5 minutes", "Finished in 1 hour"
        static func durationCompleted(minutes: Int) -> String {
            "Finished in \(formatDuration(minutes: minutes))"
        }

        /// Duration display for completed tasks from TimeInterval
        static func durationCompleted(seconds: TimeInterval) -> String {
            durationCompleted(minutes: Int(seconds / 60))
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

        // MARK: - AI Status

        static let aiProcessing = "Breaking this down..."
        static let breakdownFailedTitle = "Task Added"
        static let breakdownFailedMessage = "Your task was added, but we couldn't break it into steps this time. You can still work on it!"

        // MARK: - AI Unavailability Alerts

        static let aiAlertTitleUnavailable = "AI Features Unavailable"
        static let aiAlertTitleSettingUp = "Setting Up AI Features"

        static let aiAlertDeviceNotSupported = "This device doesn't support on-device AI. You can still use FocusFlow, but some features won't be available."
        static let aiAlertIntelligenceOff = "Enable Apple Intelligence in Settings for the full experience. You can still use the app without it."
        static let aiAlertModelNotReady = "AI features are still setting up. They should be ready soon."
        static let aiAlertUnknown = "Some features aren't available right now. You can still use the app."

        // MARK: - AI Unavailability Banners (brief, for banners)

        static let aiBannerDeviceNotSupported = "Some features unavailable on this device"
        static let aiBannerIntelligenceOff = "Enable Apple Intelligence for the full experience"
        static let aiBannerModelNotReady = "AI features are still setting up"
        static let aiBannerUnknown = "Some features unavailable"
    }
}
