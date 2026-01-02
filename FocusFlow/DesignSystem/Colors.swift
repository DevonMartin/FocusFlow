//
//  Colors.swift
//  FocusFlow
//
//  Design system colors — ADHD-friendly palette with calming teals.
//  NEVER use bright red, neon yellow, or traffic-light progressions.
//

import SwiftUI

enum DesignSystem {
    enum Colors {
        // MARK: - Primary Palette (calming blues and teals)

        /// Soft teal — primary brand color
        static let primary = Color(hex: "4A90A4")

        /// Light teal — secondary actions, backgrounds
        static let secondary = Color(hex: "7BB3C0")

        /// Muted teal-green — accent highlights
        static let accent = Color(hex: "5D9B9B")

        // MARK: - Semantic Colors

        /// Soft green — success, completion (never red for failure)
        static let gentle = Color(hex: "8FBC8F")

        /// Gray-blue — neutral states, disabled
        static let neutral = Color(hex: "B8C4CE")

        /// Soft tan — warnings (NOT red/orange)
        static let warning = Color(hex: "DEB887")

        // MARK: - Text

        /// Dark blue-gray — primary text
        static let text = Color(hex: "2C3E50")

        /// Medium gray — secondary text, hints
        static let textSecondary = Color(hex: "7F8C8D")

        // MARK: - Backgrounds

        /// Very light gray-blue — main background
        static let background = Color(hex: "F8FAFB")

        /// Pure white — cards, surfaces
        static let surface = Color.white
    }
}

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#if DEBUG
#Preview("Color Palette") {
	ScrollView {
		VStack(spacing: 16) {
			ColorRow(name: "Primary", color: DesignSystem.Colors.primary)
			ColorRow(name: "Secondary", color: DesignSystem.Colors.secondary)
			ColorRow(name: "Accent", color: DesignSystem.Colors.accent)
			ColorRow(name: "Gentle", color: DesignSystem.Colors.gentle)
			ColorRow(name: "Neutral", color: DesignSystem.Colors.neutral)
			ColorRow(name: "Warning", color: DesignSystem.Colors.warning)
			ColorRow(name: "Text", color: DesignSystem.Colors.text)
			ColorRow(name: "Text Secondary", color: DesignSystem.Colors.textSecondary)
			ColorRow(name: "Background", color: DesignSystem.Colors.background)
			ColorRow(name: "Surface", color: DesignSystem.Colors.surface)
		}
		.padding()
	}
}

private struct ColorRow: View {
	let name: String
	let color: Color
	
	var body: some View {
		HStack {
			RoundedRectangle(cornerRadius: 8)
				.fill(color)
				.frame(width: 60, height: 60)
				.overlay {
					RoundedRectangle(cornerRadius: 8)
						.stroke(Color.gray.opacity(0.3), lineWidth: 1)
				}
			
			Text(name)
				.font(.headline)
			
			Spacer()
		}
		.padding()
		.background(Color.white)
		.cornerRadius(12)
	}
}
#endif
