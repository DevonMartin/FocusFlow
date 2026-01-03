//
//  GentleButton.swift
//  FocusFlow
//
//  A calm, approachable button using the design system.
//

import SwiftUI

struct GentleButton: View {
    let title: String
    let icon: String?
    let style: Style
    let action: () -> Void

    enum Style {
        case primary
        case secondary
        case subtle

        var backgroundColor: Color {
            switch self {
            case .primary: DesignSystem.Colors.primary
            case .secondary: DesignSystem.Colors.secondary
            case .subtle: DesignSystem.Colors.surface
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary, .secondary: .white
            case .subtle: DesignSystem.Colors.text
            }
        }

        var borderColor: Color? {
            switch self {
            case .subtle: DesignSystem.Colors.neutral
            default: nil
            }
        }
    }

    init(
        _ title: String,
        icon: String? = nil,
        style: Style = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.body.weight(.medium))
                }
                Text(title)
                    .font(DesignSystem.Typography.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(style.backgroundColor)
            .foregroundStyle(style.foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                if let borderColor = style.borderColor {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("GentleButton Styles") {
    VStack(spacing: 16) {
        GentleButton("Start Task", icon: "play.fill", style: .primary) {}
        GentleButton("Add Step", icon: "plus", style: .secondary) {}
        GentleButton("Cancel", style: .subtle) {}
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
#endif
