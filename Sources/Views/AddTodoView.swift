import SwiftUI

struct AddTodoView: View {
    @EnvironmentObject var store: TodoStore
    @Environment(\.dismiss) var dismiss

    // Form state
    @State private var title: String = ""
    @State private var startTime: Date = defaultStart()
    @State private var endTime: Date = defaultEnd()
    @State private var priority: TodoPriority = .medium
    @State private var notes: String = ""
    @State private var errorMsg: String? = nil

    // Optional: editing existing todo
    var editingTodo: Todo? = nil

    var body: some View {
        ZStack {
            TerminalTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerBar

                Divider().background(TerminalTheme.border)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        titleField
                        timeFields
                        priorityPicker
                        notesField

                        if let err = errorMsg {
                            Text("ERR: \(err)")
                                .font(TerminalTheme.small)
                                .foregroundColor(TerminalTheme.red)
                                .glowEffect(TerminalTheme.red)
                        }
                    }
                    .padding(20)
                }

                Divider().background(TerminalTheme.border)
                actionBar
            }
        }
        .frame(width: 420, height: 480)
        .onAppear { populateIfEditing() }
    }

    // MARK: - Subviews

    private var headerBar: some View {
        HStack {
            Text(editingTodo == nil ? "> NEW TASK" : "> EDIT TASK")
                .font(TerminalTheme.header)
                .foregroundColor(TerminalTheme.cyan)
                .glowEffect(TerminalTheme.cyan)
            Spacer()
            Text("[ ESC to cancel ]")
                .font(TerminalTheme.micro)
                .foregroundColor(TerminalTheme.primaryDim)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(TerminalTheme.surface)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("TASK TITLE")
            HStack(spacing: 4) {
                Text(">")
                    .font(TerminalTheme.body)
                    .foregroundColor(TerminalTheme.primaryDim)
                TextField("describe the mission...", text: $title)
                    .textFieldStyle(.plain)
                    .font(TerminalTheme.body)
                    .foregroundColor(TerminalTheme.primary)
                    .glowEffect(radius: 2)
            }
            .padding(8)
            .terminalBorder(TerminalTheme.border)
        }
    }

    private var timeFields: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("START TIME")
                timePickerField($startTime)
            }
            Text("─►")
                .font(TerminalTheme.body)
                .foregroundColor(TerminalTheme.primaryDim)
                .padding(.top, 20)
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("END TIME")
                timePickerField($endTime)
            }
        }
    }

    private func timePickerField(_ binding: Binding<Date>) -> some View {
        DatePicker("", selection: binding, displayedComponents: .hourAndMinute)
            .datePickerStyle(.field)
            .labelsHidden()
            .colorScheme(.dark)
            .accentColor(TerminalTheme.cyan)
            .font(TerminalTheme.body)
            .padding(6)
            .terminalBorder(TerminalTheme.border)
    }

    private var priorityPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("PRIORITY")
            HStack(spacing: 8) {
                ForEach(TodoPriority.allCases, id: \.self) { p in
                    Button {
                        priority = p
                    } label: {
                        Text("\(p.symbol) \(p.rawValue)")
                            .font(TerminalTheme.small)
                            .foregroundColor(priority == p ? TerminalTheme.background : p.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(priority == p ? p.color : Color.clear)
                            .terminalBorder(p.color)
                    }
                    .buttonStyle(.plain)
                    .glowEffect(p.color, radius: priority == p ? 4 : 1)
                }
            }
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("NOTES  (optional)")
            TextEditor(text: $notes)
                .font(TerminalTheme.small)
                .foregroundColor(TerminalTheme.primary.opacity(0.8))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(height: 70)
                .padding(6)
                .terminalBorder(TerminalTheme.borderDim)
        }
    }

    private var actionBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Text("[ CANCEL ]")
                    .font(TerminalTheme.body)
                    .foregroundColor(TerminalTheme.primaryDim)
            }
            .buttonStyle(.plain)
            .glowEffect(TerminalTheme.primaryDim, radius: 2)

            Spacer()

            Button {
                commitTodo()
            } label: {
                Text(editingTodo == nil ? "[ CREATE ▶ ]" : "[ SAVE ▶ ]")
                    .font(TerminalTheme.body)
                    .foregroundColor(TerminalTheme.background)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(TerminalTheme.primary)
            }
            .buttonStyle(.plain)
            .glowEffect()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(TerminalTheme.surface)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(TerminalTheme.micro)
            .foregroundColor(TerminalTheme.primaryDim)
            .tracking(2)
    }

    // MARK: - Logic

    private func commitTodo() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMsg = "TASK TITLE CANNOT BE EMPTY"
            return
        }
        guard endTime > startTime else {
            errorMsg = "END TIME MUST BE AFTER START TIME"
            return
        }

        let today = Calendar.current.startOfDay(for: Date())
        let start = Calendar.current.date(
            bySettingHour: Calendar.current.component(.hour, from: startTime),
            minute: Calendar.current.component(.minute, from: startTime),
            second: 0, of: today
        ) ?? startTime
        let end = Calendar.current.date(
            bySettingHour: Calendar.current.component(.hour, from: endTime),
            minute: Calendar.current.component(.minute, from: endTime),
            second: 0, of: today
        ) ?? endTime

        if var editing = editingTodo {
            editing.title = trimmed
            editing.startTime = start
            editing.endTime = end
            editing.priority = priority
            editing.notes = notes
            store.updateTodo(editing)
        } else {
            let todo = Todo(
                title: trimmed,
                startTime: start,
                endTime: end,
                notes: notes,
                priority: priority
            )
            store.addTodo(todo)
        }
        dismiss()
    }

    private func populateIfEditing() {
        guard let t = editingTodo else { return }
        title = t.title
        startTime = t.startTime
        endTime = t.endTime
        priority = t.priority
        notes = t.notes
    }

    private static func defaultStart() -> Date {
        let now = Date()
        let c = Calendar.current
        var comps = c.dateComponents([.year, .month, .day, .hour], from: now)
        comps.hour = (comps.hour ?? 9) + 1
        comps.minute = 0
        return c.date(from: comps) ?? now
    }

    private static func defaultEnd() -> Date {
        let start = defaultStart()
        return start.addingTimeInterval(3600)
    }
}
