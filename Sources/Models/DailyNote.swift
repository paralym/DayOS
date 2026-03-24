import Foundation

struct AgentSuggestion: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var priority: TodoPriority
    var estimatedMinutes: Int
    var reason: String
    var isDismissed: Bool = false
}

struct DailyNote: Codable {
    var date: Date
    var rawContent: String = ""
    var organizedContent: String = ""
    var suggestions: [AgentSuggestion] = []
    var lastProcessed: Date? = nil
}
