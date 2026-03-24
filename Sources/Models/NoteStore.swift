import Foundation

class NoteStore: ObservableObject {
    @Published var todayNote: DailyNote = DailyNote(date: Date())
    @Published var processingState: ProcessingState = .idle

    enum ProcessingState: Equatable {
        case idle
        case processing
        case updated(Date)
        case error(String)
    }

    private var processingTask: Task<Void, Never>?
    private let storageKey = "dayos_notes_v2"
    private var allNotes: [String: DailyNote] = [:]

    init() {
        loadNotes()
        todayNote = allNotes[Self.todayKey] ?? DailyNote(date: Date())
    }

    // MARK: - Key helpers

    static var todayKey: String { dateKey(for: Date()) }

    static func dateKey(for date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }

    // MARK: - Note mutations

    func updateRawContent(_ content: String) {
        todayNote.rawContent = content
        persist()
        scheduleAgentProcessing()
    }

    func dismissSuggestion(id: UUID) {
        todayNote.suggestions.removeAll { $0.id == id }
        persist()
    }

    func markSuggestionAdded(id: UUID) {
        if let i = todayNote.suggestions.firstIndex(where: { $0.id == id }) {
            todayNote.suggestions[i].isDismissed = true
        }
        persist()
    }

    // MARK: - Agent processing (debounced)

    func scheduleAgentProcessing() {
        processingTask?.cancel()
        guard ClaudeAPIManager.shared.hasKey,
              !todayNote.rawContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        processingTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            await self?.runAgentProcessing()
        }
    }

    @MainActor
    func runAgentProcessing() async {
        let content = todayNote.rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        processingState = .processing

        do {
            let result = try await ClaudeAPIManager.shared.processNote(content: content)
            todayNote.organizedContent = result.organizedContent
            todayNote.suggestions = result.suggestions
            todayNote.lastProcessed = Date()
            persist()
            processingState = .updated(Date())
        } catch {
            processingState = .error(error.localizedDescription)
        }
    }

    // MARK: - Persistence

    private func persist() {
        allNotes[Self.todayKey] = todayNote
        if let data = try? JSONEncoder().encode(allNotes) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadNotes() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: DailyNote].self, from: data) else { return }
        allNotes = decoded
    }
}
