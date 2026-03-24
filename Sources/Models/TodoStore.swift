import Foundation
import Combine

class TodoStore: ObservableObject {
    @Published var todos: [Todo] = []
    @Published var selectedTodoId: UUID? = nil

    private let storageKey = "dayos_todos_v1"

    init() {
        loadTodos()
        setupNotificationObserver()
    }

    // MARK: - Accessors

    var todosForToday: [Todo] {
        todos
            .filter { Calendar.current.isDateInToday($0.startTime) }
            .sorted { $0.startTime < $1.startTime }
    }

    var selectedTodo: Todo? {
        guard let id = selectedTodoId else { return nil }
        return todos.first { $0.id == id }
    }

    // MARK: - CRUD

    func addTodo(_ todo: Todo) {
        todos.append(todo)
        save()
        NotificationManager.shared.scheduleHalfway(for: todo)
    }

    func updateTodo(_ todo: Todo) {
        guard let idx = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[idx] = todo
        save()
        NotificationManager.shared.cancelHalfway(for: todo.id)
        NotificationManager.shared.scheduleHalfway(for: todo)
    }

    func deleteTodo(id: UUID) {
        NotificationManager.shared.cancelHalfway(for: id)
        todos.removeAll { $0.id == id }
        if selectedTodoId == id { selectedTodoId = nil }
        save()
    }

    func toggleComplete(id: UUID) {
        guard let idx = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[idx].isCompleted.toggle()
        save()
    }

    func select(_ todo: Todo?) {
        selectedTodoId = todo?.id
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(todos) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadTodos() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Todo].self, from: data) else { return }
        todos = decoded
    }

    // MARK: - Notification response

    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .todoCompletedFromNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let id = note.userInfo?["todoId"] as? UUID {
                self?.toggleComplete(id: id)
            }
        }
    }
}

extension Notification.Name {
    static let todoCompletedFromNotification = Notification.Name("dayos.todoCompleted")
}
