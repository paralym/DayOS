import SwiftUI

// MARK: - Presets

enum TerminalPreset: String, CaseIterable {
    case phosphor  = "PHOSPHOR"
    case amber     = "AMBER"
    case cyanPunk  = "CYAN"
    case ghost     = "GHOST"

    var displayName: String { rawValue }

    // Primary text color
    var primary: Color {
        switch self {
        case .phosphor: return Color(red: 0.18, green: 0.98, blue: 0.18)
        case .amber:    return Color(red: 1.00, green: 0.68, blue: 0.00)
        case .cyanPunk: return Color(red: 0.00, green: 0.90, blue: 0.90)
        case .ghost:    return Color(red: 0.78, green: 0.88, blue: 0.78)
        }
    }

    var primaryDim: Color {
        switch self {
        case .phosphor: return Color(red: 0.08, green: 0.45, blue: 0.08)
        case .amber:    return Color(red: 0.50, green: 0.33, blue: 0.00)
        case .cyanPunk: return Color(red: 0.00, green: 0.42, blue: 0.42)
        case .ghost:    return Color(red: 0.35, green: 0.42, blue: 0.35)
        }
    }

    var background: Color {
        switch self {
        case .phosphor: return Color(red: 0.02, green: 0.04, blue: 0.02)
        case .amber:    return Color(red: 0.04, green: 0.03, blue: 0.01)
        case .cyanPunk: return Color(red: 0.01, green: 0.04, blue: 0.05)
        case .ghost:    return Color(red: 0.04, green: 0.04, blue: 0.04)
        }
    }

    var surface: Color {
        switch self {
        case .phosphor: return Color(red: 0.05, green: 0.09, blue: 0.05)
        case .amber:    return Color(red: 0.08, green: 0.06, blue: 0.02)
        case .cyanPunk: return Color(red: 0.02, green: 0.08, blue: 0.09)
        case .ghost:    return Color(red: 0.08, green: 0.08, blue: 0.08)
        }
    }

    var border: Color {
        switch self {
        case .phosphor: return Color(red: 0.12, green: 0.35, blue: 0.12)
        case .amber:    return Color(red: 0.40, green: 0.28, blue: 0.04)
        case .cyanPunk: return Color(red: 0.04, green: 0.32, blue: 0.32)
        case .ghost:    return Color(red: 0.28, green: 0.30, blue: 0.28)
        }
    }

    var borderDim: Color {
        switch self {
        case .phosphor: return Color(red: 0.07, green: 0.18, blue: 0.07)
        case .amber:    return Color(red: 0.20, green: 0.14, blue: 0.02)
        case .cyanPunk: return Color(red: 0.02, green: 0.16, blue: 0.16)
        case .ghost:    return Color(red: 0.14, green: 0.16, blue: 0.14)
        }
    }
}

// MARK: - Store

class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    @Published var preset: TerminalPreset {
        didSet { UserDefaults.standard.set(preset.rawValue, forKey: "dayos_theme") }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "dayos_theme") ?? ""
        preset = TerminalPreset(rawValue: saved) ?? .phosphor
    }
}
