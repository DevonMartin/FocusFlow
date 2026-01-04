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
