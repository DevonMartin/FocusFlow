//
//  Typography.swift
//  FocusFlow
//
//  Design system typography — rounded fonts for friendliness,
//  monospaced digits for timers.
//

import SwiftUI

extension DesignSystem {
    enum Typography {
        // MARK: - Headings

        /// Large title — 34pt bold rounded
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)

        /// Title — 28pt semibold rounded
        static let title = Font.system(size: 28, weight: .semibold, design: .rounded)

        /// Headline — 17pt semibold rounded
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)

        // MARK: - Body Text

        /// Body — 17pt regular default
        static let body = Font.system(size: 17, weight: .regular, design: .default)

        /// Callout — 16pt regular default
        static let callout = Font.system(size: 16, weight: .regular, design: .default)

        /// Caption — 12pt regular default
        static let caption = Font.system(size: 12, weight: .regular, design: .default)

        // MARK: - Timer Display

        /// Large timer — 48pt medium rounded, monospaced digits
        static let timer = Font.system(size: 48, weight: .medium, design: .rounded).monospacedDigit()

        /// Small timer — 28pt medium rounded, monospaced digits
        static let timerSmall = Font.system(size: 28, weight: .medium, design: .rounded).monospacedDigit()
    }
}
