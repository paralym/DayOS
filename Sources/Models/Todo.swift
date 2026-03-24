import Foundation
import SwiftUI

enum TodoPriority: String, Codable, CaseIterable {
    case low = "LOW"
    case medium = "MED"
    case high = "HIGH"
    case critical = "CRIT"

    var color: Color {
        switch self {
        case .low:      return Color(red: 0.18, green: 0.98, blue: 0.18)   // green
        case .medium:   return Color(red: 0.0,  green: 0.88, blue: 0.88)   // cyan
        case .high:     return Color(red: 1.0,  green: 0.72, blue: 0.0)    // amber
        case .critical: return Color(red: 1.0,  green: 0.22, blue: 0.22)   // red
        }
    }

    var symbol: String {
        switch self {
        case .low:      return "▪"
        case .medium:   return "◆"
        case .high:     return "▲"
        case .critical: return "★"
        }
    }
}

struct Todo: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var startTime: Date
    var endTime: Date
    var isCompleted: Bool = false
    var notes: String = ""
    var priority: TodoPriority = .medium

    // MARK: - Computed
    var duration: TimeInterval { endTime.timeIntervalSince(startTime) }
    var midpointTime: Date { startTime.addingTimeInterval(duration / 2) }

    var progress: Double {
        let now = Date()
        guard now >= startTime else { return 0 }
        guard now <= endTime   else { return 1 }
        return now.timeIntervalSince(startTime) / duration
    }

    var isActive: Bool {
        let now = Date()
        return now >= startTime && now <= endTime
    }

    var isPast: Bool { Date() > endTime }
    var isFuture: Bool { Date() < startTime }

    var statusSymbol: String {
        if isCompleted { return "[✓]" }
        if isActive    { return "[►]" }
        if isPast      { return "[·]" }
        return "[ ]"
    }

    var durationString: String {
        let mins = Int(duration / 60)
        if mins < 60 { return "\(mins)m" }
        let h = mins / 60
        let m = mins % 60
        return m == 0 ? "\(h)h" : "\(h)h\(m)m"
    }
}

// MARK: - Date helpers
extension Date {
    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: self)
    }

    var hourMinuteComponents: (hour: Int, minute: Int) {
        let c = Calendar.current.dateComponents([.hour, .minute], from: self)
        return (c.hour ?? 0, c.minute ?? 0)
    }
}
