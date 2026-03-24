import Foundation

// MARK: - Scheduled Task from AI
struct AIScheduledTask: Identifiable {
    let id = UUID()
    var title: String
    var startTime: String   // "HH:MM"
    var endTime: String     // "HH:MM"
    var priority: TodoPriority
    var notes: String
    var isSelected: Bool = true

    // Convert to a Todo for the store
    func toTodo() -> Todo? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let start = parseTime(startTime, base: today),
              let end   = parseTime(endTime, base: today),
              end > start else { return nil }

        return Todo(
            title: title,
            startTime: start,
            endTime: end,
            notes: notes,
            priority: priority
        )
    }

    private func parseTime(_ str: String, base: Date) -> Date? {
        let parts = str.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: base)
    }
}

struct PlanResult {
    let tasks: [AIScheduledTask]
    let reasoning: String
}

// MARK: - Claude API Manager
class ClaudeAPIManager: ObservableObject {
    static let shared = ClaudeAPIManager()

    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "dayos_claude_api_key") }
    }

    var hasKey: Bool { !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }

    private init() {
        apiKey = UserDefaults.standard.string(forKey: "dayos_claude_api_key") ?? ""
    }

    // MARK: - Plan Tasks

    func planTasks(input: String) async throws -> PlanResult {
        guard hasKey else { throw APIError.noAPIKey }

        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        let dateStr = formatter.string(from: now)
        formatter.dateFormat = "HH:mm"
        let timeStr = formatter.string(from: now)

        let systemPrompt = """
        You are an expert personal schedule planner. Your job is to analyze a user's task list and schedule them optimally for today.

        Guidelines:
        - Schedule tasks between 08:00–22:00 unless the user specifies otherwise
        - Consider realistic time estimates for each task type
        - Group related tasks together when possible
        - Put high-energy/focus tasks in the morning
        - Leave buffer time between tasks (5-15 min)
        - Prioritize based on urgency and importance
        - You MUST call the schedule_tasks tool with your result
        """

        let userMessage = """
        Today is \(dateStr). Current time is \(timeStr).

        Please schedule these tasks for me today:

        \(input)
        """

        let tool: [String: Any] = [
            "name": "schedule_tasks",
            "description": "Output the optimized daily schedule as structured data",
            "input_schema": [
                "type": "object",
                "properties": [
                    "reasoning": [
                        "type": "string",
                        "description": "Brief explanation of how you organized the schedule and why"
                    ],
                    "tasks": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "title":     ["type": "string", "description": "Clear task name"],
                                "startTime": ["type": "string", "description": "Start time in HH:MM (24h) format"],
                                "endTime":   ["type": "string", "description": "End time in HH:MM (24h) format"],
                                "priority":  ["type": "string", "enum": ["LOW", "MED", "HIGH", "CRIT"]],
                                "notes":     ["type": "string", "description": "Optional tips or sub-tasks"]
                            ],
                            "required": ["title", "startTime", "endTime", "priority", "notes"]
                        ]
                    ]
                ],
                "required": ["reasoning", "tasks"]
            ]
        ]

        let body: [String: Any] = [
            "model": "claude-opus-4-6",
            "max_tokens": 4096,
            "system": systemPrompt,
            "tools": [tool],
            "tool_choice": ["type": "tool", "name": "schedule_tasks"],
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 60

        let (responseData, httpResponse) = try await URLSession.shared.data(for: request)

        guard let http = httpResponse as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 { throw APIError.invalidAPIKey }
        if http.statusCode == 429 { throw APIError.rateLimited }
        guard http.statusCode == 200 else {
            let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any]
            let msg = errorJson?["error"] as? [String: Any]
            throw APIError.apiError(msg?["message"] as? String ?? "HTTP \(http.statusCode)")
        }

        return try parseResponse(responseData)
    }

    // MARK: - Parse Response

    private func parseResponse(_ data: Data) throws -> PlanResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw APIError.parseError("Invalid response structure")
        }

        // Find the tool_use block
        guard let toolUse = content.first(where: { $0["type"] as? String == "tool_use" }),
              let input = toolUse["input"] as? [String: Any] else {
            throw APIError.parseError("No tool_use block in response")
        }

        let reasoning = input["reasoning"] as? String ?? ""
        guard let rawTasks = input["tasks"] as? [[String: Any]] else {
            throw APIError.parseError("No tasks array in response")
        }

        let tasks: [AIScheduledTask] = rawTasks.compactMap { t in
            guard let title     = t["title"]     as? String,
                  let startTime = t["startTime"] as? String,
                  let endTime   = t["endTime"]   as? String,
                  let prioRaw   = t["priority"]  as? String,
                  let priority  = TodoPriority(rawValue: prioRaw) else { return nil }
            let notes = t["notes"] as? String ?? ""
            return AIScheduledTask(title: title, startTime: startTime, endTime: endTime,
                                   priority: priority, notes: notes)
        }

        guard !tasks.isEmpty else { throw APIError.parseError("AI returned no tasks") }
        return PlanResult(tasks: tasks, reasoning: reasoning)
    }
}

// MARK: - Errors
enum APIError: LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case rateLimited
    case invalidResponse
    case parseError(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:           return "API key not configured. Tap the key icon to add it."
        case .invalidAPIKey:      return "Invalid API key. Check your Anthropic API key."
        case .rateLimited:        return "Rate limited. Please wait a moment and try again."
        case .invalidResponse:    return "Received invalid response from API."
        case .parseError(let m):  return "Parse error: \(m)"
        case .apiError(let m):    return "API error: \(m)"
        }
    }
}
