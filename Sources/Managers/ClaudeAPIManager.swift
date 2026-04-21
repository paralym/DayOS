import Foundation

// MARK: - Provider
enum APIProvider: String, CaseIterable {
    case anthropic   = "Anthropic"
    case openRouter  = "OpenRouter"

    var baseURL: String {
        switch self {
        case .anthropic:  return "https://api.anthropic.com/v1/messages"
        case .openRouter: return "https://openrouter.ai/api/v1/chat/completions"
        }
    }

    var defaultModel: String {
        switch self {
        case .anthropic:  return "claude-opus-4-6"
        case .openRouter: return "anthropic/claude-opus-4"
        }
    }
}

// MARK: - Scheduled Task from AI
struct AIScheduledTask: Identifiable {
    let id = UUID()
    var title: String
    var startTime: String   // "HH:MM"
    var endTime: String     // "HH:MM"
    var priority: TodoPriority
    var notes: String
    var isSelected: Bool = true

    func toTodo() -> Todo? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = parseTime(startTime, base: today),
              let end   = parseTime(endTime,   base: today),
              end > start else { return nil }
        return Todo(title: title, startTime: start, endTime: end, notes: notes, priority: priority)
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

    @Published var provider: APIProvider {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: "dayos_provider") }
    }
    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "dayos_api_key_\(provider.rawValue)") }
    }
    @Published var model: String {
        didSet { UserDefaults.standard.set(model, forKey: "dayos_model_\(provider.rawValue)") }
    }

    var hasKey: Bool { !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }

    private init() {
        let savedProvider = UserDefaults.standard.string(forKey: "dayos_provider") ?? ""
        let p = APIProvider(rawValue: savedProvider) ?? .anthropic
        provider = p
        apiKey = UserDefaults.standard.string(forKey: "dayos_api_key_\(p.rawValue)") ?? ""
        model   = UserDefaults.standard.string(forKey: "dayos_model_\(p.rawValue)") ?? p.defaultModel
    }

    func switchProvider(_ newProvider: APIProvider) {
        provider = newProvider
        apiKey = UserDefaults.standard.string(forKey: "dayos_api_key_\(newProvider.rawValue)") ?? ""
        model  = UserDefaults.standard.string(forKey: "dayos_model_\(newProvider.rawValue)") ?? newProvider.defaultModel
    }

    // MARK: - Plan Tasks

    func planTasks(input: String) async throws -> PlanResult {
        guard hasKey else { throw APIError.noAPIKey }

        let now = Date()
        let df  = DateFormatter()
        df.dateFormat = "EEEE, MMMM d, yyyy"; let dateStr = df.string(from: now)
        df.dateFormat = "HH:mm";              let timeStr  = df.string(from: now)

        let systemPrompt = """
        You are an expert personal schedule planner. Analyze the user's task list and schedule them optimally for today.
        Guidelines: schedule 08:00–22:00, realistic time estimates, group related tasks, \
        high-focus tasks in morning, 5–15 min buffer between tasks, prioritize by urgency/importance.
        You MUST call the schedule_tasks tool with your result.
        """

        let userMessage = "Today is \(dateStr). Current time is \(timeStr).\n\nSchedule these tasks:\n\n\(input)"

        switch provider {
        case .anthropic:
            return try await callAnthropic(system: systemPrompt, user: userMessage)
        case .openRouter:
            return try await callOpenRouter(system: systemPrompt, user: userMessage)
        }
    }

    // MARK: - Anthropic

    private func callAnthropic(system: String, user: String) async throws -> PlanResult {
        let tool: [String: Any] = [
            "name": "schedule_tasks",
            "description": "Output the optimized daily schedule",
            "input_schema": taskSchema()
        ]
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": system,
            "tools": [tool],
            "tool_choice": ["type": "tool", "name": "schedule_tasks"],
            "messages": [["role": "user", "content": user]]
        ]

        var req = URLRequest(url: URL(string: APIProvider.anthropic.baseURL)!)
        req.httpMethod = "POST"
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 60

        let data = try await perform(req)

        guard let json    = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let toolUse = content.first(where: { $0["type"] as? String == "tool_use" }),
              let input   = toolUse["input"] as? [String: Any] else {
            throw APIError.parseError("No tool_use block in Anthropic response")
        }
        return try decodePlanResult(from: input)
    }

    // MARK: - OpenRouter (OpenAI-compatible)

    private func callOpenRouter(system: String, user: String) async throws -> PlanResult {
        let tool: [String: Any] = [
            "type": "function",
            "function": [
                "name": "schedule_tasks",
                "description": "Output the optimized daily schedule",
                "parameters": taskSchema()
            ]
        ]
        let body: [String: Any] = [
            "model": model,
            "tools": [tool],
            "tool_choice": ["type": "function", "function": ["name": "schedule_tasks"]],
            "messages": [
                ["role": "system", "content": system],
                ["role": "user",   "content": user]
            ]
        ]

        var req = URLRequest(url: URL(string: APIProvider.openRouter.baseURL)!)
        req.httpMethod = "POST"
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.setValue("application/json",    forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)",     forHTTPHeaderField: "Authorization")
        req.setValue("DayOS/1.0",           forHTTPHeaderField: "HTTP-Referer")
        req.timeoutInterval = 60

        let data = try await perform(req)

        guard let json    = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let msg     = choices.first?["message"] as? [String: Any],
              let calls   = msg["tool_calls"] as? [[String: Any]],
              let fn      = calls.first?["function"] as? [String: Any],
              let argsStr = fn["arguments"] as? String,
              let argsData = argsStr.data(using: .utf8),
              let input   = try JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
            throw APIError.parseError("No tool_calls in OpenRouter response")
        }
        return try decodePlanResult(from: input)
    }

    // MARK: - Shared helpers

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 { throw APIError.invalidAPIKey }
        if http.statusCode == 429 { throw APIError.rateLimited }
        guard http.statusCode == 200 else {
            let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg = (errorJson?["error"] as? [String: Any])?["message"] as? String
            throw APIError.apiError(msg ?? "HTTP \(http.statusCode)")
        }
        return data
    }

    private func taskSchema() -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "reasoning": ["type": "string", "description": "Brief explanation of schedule decisions"],
                "tasks": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "title":     ["type": "string"],
                            "startTime": ["type": "string", "description": "HH:MM 24h"],
                            "endTime":   ["type": "string", "description": "HH:MM 24h"],
                            "priority":  ["type": "string", "enum": ["LOW", "MED", "HIGH", "CRIT"]],
                            "notes":     ["type": "string"]
                        ],
                        "required": ["title", "startTime", "endTime", "priority", "notes"]
                    ]
                ]
            ],
            "required": ["reasoning", "tasks"]
        ]
    }

    // MARK: - Note Processing

    struct NoteProcessResult {
        let organizedContent: String
        let suggestions: [AgentSuggestion]
    }

    func processNote(content: String, previousOrganized: String = "", existingTodos: [Todo] = []) async throws -> NoteProcessResult {
        guard hasKey else { throw APIError.noAPIKey }

        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        let timeStr = df.string(from: Date())

        let system = """
        You are a productivity assistant silently observing the user's daily notes.
        Your role: incrementally update the organized note and surface what matters most.

        Rules:
        - Keep very close to the user's original words — don't invent new tasks
        - organizedContent: if a previous organized note exists, UPDATE it by merging in new/changed \
        content from the raw notes — preserve existing structure, only add or revise what changed. \
        If no previous note, create a clean structured markdown bullet list.
        - suggestions: create exactly ONE suggestion entry per item/bullet in the organizedContent — \
        every item must appear, do not skip or merge any. Use realistic time estimates. \
        Consider existing todos to avoid time conflicts and respect task dependencies. \
        AFTER all task entries, append one extra rest/break entry (15–30 min) if there are 3+ task entries \
        — the break is always additional, never replacing a real task entry.
        - Be concise — this is a terminal UI with limited space
        - You MUST call the process_note tool
        """

        let todosBlock: String
        if existingTodos.isEmpty {
            todosBlock = "(none)"
        } else {
            todosBlock = existingTodos.map { t in
                let status = t.isCompleted ? "✓" : (t.isActive ? "►" : " ")
                return "[\(status)] \(t.startTime.timeString)–\(t.endTime.timeString) \(t.title) [\(t.priority.rawValue)]"
            }.joined(separator: "\n")
        }

        let prevBlock = previousOrganized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "(none yet)"
            : previousOrganized

        let user = """
        Current time: \(timeStr)

        Today's scheduled tasks:
        \(todosBlock)

        Previous organized note:
        \(prevBlock)

        Updated raw notes:
        \(content)
        """

        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "organizedContent": ["type": "string", "description": "Structured markdown version of the note"],
                "suggestions": [
                    "type": "array",
                    "description": "Top tasks worth adding to today's timeline",
                    "items": [
                        "type": "object",
                        "properties": [
                            "title":              ["type": "string"],
                            "priority":           ["type": "string", "enum": ["LOW", "MED", "HIGH", "CRIT"]],
                            "estimatedMinutes":   ["type": "integer"],
                            "reason":             ["type": "string", "description": "One sentence why this matters now"]
                        ],
                        "required": ["title", "priority", "estimatedMinutes", "reason"]
                    ]
                ]
            ],
            "required": ["organizedContent", "suggestions"]
        ]

        let input: [String: Any]
        switch provider {
        case .anthropic:
            let tool: [String: Any] = ["name": "process_note", "description": "Output organized note and suggestions", "input_schema": schema]
            let body: [String: Any] = [
                "model": model, "max_tokens": 2048, "system": system,
                "tools": [tool], "tool_choice": ["type": "tool", "name": "process_note"],
                "messages": [["role": "user", "content": user]]
            ]
            var req = URLRequest(url: URL(string: APIProvider.anthropic.baseURL)!)
            req.httpMethod = "POST"
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            req.timeoutInterval = 45
            let data = try await perform(req)
            guard let json    = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let toolUse = content.first(where: { $0["type"] as? String == "tool_use" }),
                  let inp     = toolUse["input"] as? [String: Any] else {
                throw APIError.parseError("No tool_use in note response")
            }
            input = inp

        case .openRouter:
            let tool: [String: Any] = ["type": "function", "function": ["name": "process_note", "description": "Output organized note", "parameters": schema]]
            let body: [String: Any] = [
                "model": model,
                "tools": [tool],
                "tool_choice": ["type": "function", "function": ["name": "process_note"]],
                "messages": [["role": "system", "content": system], ["role": "user", "content": user]]
            ]
            var req = URLRequest(url: URL(string: APIProvider.openRouter.baseURL)!)
            req.httpMethod = "POST"
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            req.setValue("DayOS/1.0", forHTTPHeaderField: "HTTP-Referer")
            req.timeoutInterval = 45
            let data = try await perform(req)
            guard let json    = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let msg     = choices.first?["message"] as? [String: Any],
                  let calls   = msg["tool_calls"] as? [[String: Any]],
                  let fn      = calls.first?["function"] as? [String: Any],
                  let argsStr = fn["arguments"] as? String,
                  let argsData = argsStr.data(using: .utf8),
                  let inp     = try JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
                throw APIError.parseError("No tool_calls in note response")
            }
            input = inp
        }

        let organized = input["organizedContent"] as? String ?? content
        let rawSugs = input["suggestions"] as? [[String: Any]] ?? []
        let suggestions: [AgentSuggestion] = rawSugs.compactMap { s in
            guard let title  = s["title"]            as? String,
                  let pRaw   = s["priority"]          as? String,
                  let prio   = TodoPriority(rawValue: pRaw),
                  let mins   = s["estimatedMinutes"]  as? Int,
                  let reason = s["reason"]            as? String else { return nil }
            return AgentSuggestion(title: title, priority: prio, estimatedMinutes: mins, reason: reason)
        }
        return NoteProcessResult(organizedContent: organized, suggestions: suggestions)
    }

    private func decodePlanResult(from input: [String: Any]) throws -> PlanResult {
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
            return AIScheduledTask(title: title, startTime: startTime, endTime: endTime,
                                   priority: priority, notes: t["notes"] as? String ?? "")
        }
        guard !tasks.isEmpty else { throw APIError.parseError("AI returned no tasks") }
        return PlanResult(tasks: tasks, reasoning: reasoning)
    }
}

// MARK: - Errors
enum APIError: LocalizedError {
    case noAPIKey, invalidAPIKey, rateLimited, invalidResponse
    case parseError(String), apiError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:           return "API key not set. Click ⚡ AI → key icon."
        case .invalidAPIKey:      return "Invalid API key."
        case .rateLimited:        return "Rate limited — wait a moment and retry."
        case .invalidResponse:    return "Invalid response from API."
        case .parseError(let m):  return "Parse error: \(m)"
        case .apiError(let m):    return "API error: \(m)"
        }
    }
}
