import SwiftUI

struct TimelineView: View {
    @EnvironmentObject var store: TodoStore
    @State private var currentTime = Date()
    @State private var editingTodo: Todo? = nil
    @State private var showEdit = false

    private let hourH = TerminalTheme.hourHeight
    private let timeColW = TerminalTheme.timeColumnWidth
    private let totalH: CGFloat = TerminalTheme.hourHeight * 24

    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Invisible size anchor
                    Color.clear.frame(width: 1, height: totalH)

                    // Hour grid
                    ForEach(0..<24, id: \.self) { hour in
                        hourRow(hour: hour)
                            .offset(y: CGFloat(hour) * hourH)
                            .id(hour)
                    }

                    // Todo blocks
                    ForEach(store.todosForToday) { todo in
                        todoBlock(todo)
                            .frame(height: max(blockH(todo), 28))
                            .padding(.leading, timeColW + 2)
                            .padding(.trailing, 6)
                            .offset(y: yOffset(todo.startTime))
                            .onTapGesture {
                                editingTodo = todo
                                showEdit = true
                            }
                    }

                    // Current time line
                    currentTimeLine
                        .offset(y: currentYOffset)
                }
                .frame(maxWidth: .infinity)
            }
            .onAppear {
                let hour = Calendar.current.component(.hour, from: Date())
                proxy.scrollTo(max(hour - 2, 0), anchor: .top)
            }
            .onReceive(minuteTimer) { _ in
                currentTime = Date()
            }
        }
        .sheet(isPresented: $showEdit) {
            if let todo = editingTodo {
                TodoDetailView(todo: todo)
            }
        }
    }

    // MARK: - Hour Row

    private func hourRow(hour: Int) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Time label
            Text(String(format: "%02d:00", hour))
                .font(TerminalTheme.micro)
                .foregroundColor(TerminalTheme.primaryDim)
                .frame(width: timeColW - 8, alignment: .trailing)
                .padding(.trailing, 8)

            // Horizontal grid line
            VStack(spacing: 0) {
                Rectangle()
                    .fill(hour % 6 == 0 ? TerminalTheme.border : TerminalTheme.borderDim)
                    .frame(height: 1)

                // Half-hour marker
                Spacer()
                Rectangle()
                    .fill(TerminalTheme.borderDim.opacity(0.4))
                    .frame(height: 1)
                    .padding(.bottom, 0)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: hourH)
    }

    // MARK: - Todo Block

    private func todoBlock(_ todo: Todo) -> some View {
        let col = todo.priority.color
        let height = max(blockH(todo), 28)

        return ZStack(alignment: .topLeading) {
            // Progress fill (for active tasks)
            if todo.isActive && !todo.isCompleted {
                GeometryReader { geo in
                    Rectangle()
                        .fill(col.opacity(0.12))
                        .frame(height: geo.size.height * todo.progress)
                }
            }

            // Background
            Rectangle()
                .fill(todo.isCompleted ? col.opacity(0.05) : col.opacity(0.10))

            // Left accent bar
            HStack(spacing: 0) {
                Rectangle()
                    .fill(col.opacity(todo.isCompleted ? 0.3 : 1.0))
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(todo.statusSymbol)
                            .font(TerminalTheme.micro)
                            .foregroundColor(col.opacity(0.7))
                        Text(todo.title.uppercased())
                            .font(TerminalTheme.small)
                            .foregroundColor(todo.isCompleted ? col.opacity(0.4) : col)
                            .glowEffect(col, radius: todo.isActive ? 3 : 1)
                            .lineLimit(1)
                        Spacer()
                        Text("[\(todo.priority.rawValue)]")
                            .font(TerminalTheme.micro)
                            .foregroundColor(col.opacity(0.6))
                    }

                    if height > 40 {
                        Text("\(todo.startTime.timeString)–\(todo.endTime.timeString)  \(todo.durationString)")
                            .font(TerminalTheme.micro)
                            .foregroundColor(col.opacity(0.5))
                    }

                    if todo.isActive && height > 50 {
                        progressBar(todo: todo, color: col)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
        }
        .terminalBorder(col.opacity(0.35))
        .glowEffect(col, radius: todo.isActive && !todo.isCompleted ? 2 : 0)
    }

    private func progressBar(todo: Todo, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(color.opacity(0.15))
                    .frame(height: 3)
                Rectangle()
                    .fill(color)
                    .frame(width: geo.size.width * todo.progress, height: 3)
                    .glowEffect(color, radius: 2)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Current Time Line

    private var currentTimeLine: some View {
        HStack(spacing: 0) {
            Text(currentTime.timeString)
                .font(TerminalTheme.micro)
                .foregroundColor(TerminalTheme.red)
                .glowEffect(TerminalTheme.red)
                .frame(width: timeColW - 4, alignment: .trailing)
                .padding(.trailing, 4)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(TerminalTheme.red)
                    .frame(height: 1)
                    .glowEffect(TerminalTheme.red, radius: 3)
                Circle()
                    .fill(TerminalTheme.red)
                    .frame(width: 5, height: 5)
                    .glowEffect(TerminalTheme.red)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helpers

    private func yOffset(_ date: Date) -> CGFloat {
        let (h, m) = date.hourMinuteComponents
        return CGFloat(h * 60 + m) * hourH / 60
    }

    private func blockH(_ todo: Todo) -> CGFloat {
        CGFloat(todo.duration / 60) * hourH / 60
    }

    private var currentYOffset: CGFloat {
        yOffset(currentTime)
    }
}

// MARK: - Todo Detail / Edit Sheet
struct TodoDetailView: View {
    @EnvironmentObject var store: TodoStore
    @Environment(\.dismiss) var dismiss
    let todo: Todo

    @State private var showEdit = false
    @State private var confirmDelete = false

    var body: some View {
        ZStack {
            TerminalTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("> TASK DETAIL")
                        .font(TerminalTheme.header)
                        .foregroundColor(todo.priority.color)
                        .glowEffect(todo.priority.color)
                    Spacer()
                    Button { dismiss() } label: {
                        Text("[ ✕ ]")
                            .font(TerminalTheme.body)
                            .foregroundColor(TerminalTheme.primaryDim)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(TerminalTheme.surface)

                Divider().background(TerminalTheme.border)

                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    HStack(alignment: .top, spacing: 8) {
                        Text(todo.statusSymbol)
                            .font(TerminalTheme.body)
                            .foregroundColor(todo.priority.color.opacity(0.7))
                        Text(todo.title.uppercased())
                            .font(TerminalTheme.header)
                            .foregroundColor(todo.priority.color)
                            .glowEffect(todo.priority.color)
                    }

                    // Time info
                    HStack(spacing: 12) {
                        infoChip("START", todo.startTime.timeString)
                        Text("─►").foregroundColor(TerminalTheme.primaryDim)
                        infoChip("END", todo.endTime.timeString)
                        infoChip("DUR", todo.durationString)
                    }

                    // Priority
                    HStack(spacing: 8) {
                        Text("PRIORITY:")
                            .font(TerminalTheme.micro)
                            .foregroundColor(TerminalTheme.primaryDim)
                        Text("\(todo.priority.symbol) \(todo.priority.rawValue)")
                            .font(TerminalTheme.small)
                            .foregroundColor(todo.priority.color)
                            .glowEffect(todo.priority.color)
                    }

                    // Progress
                    if todo.isActive {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("PROGRESS:")
                                    .font(TerminalTheme.micro)
                                    .foregroundColor(TerminalTheme.primaryDim)
                                Text("\(Int(todo.progress * 100))%")
                                    .font(TerminalTheme.small)
                                    .foregroundColor(todo.priority.color)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(todo.priority.color.opacity(0.15)).frame(height: 6)
                                    Rectangle().fill(todo.priority.color)
                                        .frame(width: geo.size.width * todo.progress, height: 6)
                                        .glowEffect(todo.priority.color)
                                }
                            }
                            .frame(height: 6)
                        }
                    }

                    // Notes
                    if !todo.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOTES:")
                                .font(TerminalTheme.micro)
                                .foregroundColor(TerminalTheme.primaryDim)
                            Text(todo.notes)
                                .font(TerminalTheme.small)
                                .foregroundColor(TerminalTheme.primary.opacity(0.7))
                                .padding(8)
                                .terminalBorder(TerminalTheme.borderDim)
                        }
                    }

                    Spacer()

                    // Actions
                    HStack(spacing: 10) {
                        Button {
                            store.toggleComplete(id: todo.id)
                            dismiss()
                        } label: {
                            Text(todo.isCompleted ? "[ REOPEN ]" : "[ COMPLETE ✓ ]")
                                .font(TerminalTheme.body)
                                .foregroundColor(todo.isCompleted ? TerminalTheme.primaryDim : TerminalTheme.primary)
                        }
                        .buttonStyle(.plain)
                        .glowEffect()

                        Spacer()

                        Button {
                            showEdit = true
                        } label: {
                            Text("[ EDIT ]")
                                .font(TerminalTheme.body)
                                .foregroundColor(TerminalTheme.cyan)
                        }
                        .buttonStyle(.plain)
                        .glowEffect(TerminalTheme.cyan)

                        Button {
                            confirmDelete = true
                        } label: {
                            Text("[ DEL ]")
                                .font(TerminalTheme.body)
                                .foregroundColor(TerminalTheme.red)
                        }
                        .buttonStyle(.plain)
                        .glowEffect(TerminalTheme.red)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 400, height: 380)
        .sheet(isPresented: $showEdit) {
            AddTodoView(editingTodo: todo)
        }
        .alert("DELETE TASK?", isPresented: $confirmDelete) {
            Button("DELETE", role: .destructive) {
                store.deleteTodo(id: todo.id)
                dismiss()
            }
            Button("CANCEL", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func infoChip(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(TerminalTheme.micro)
                .foregroundColor(TerminalTheme.primaryDim)
            Text(value)
                .font(TerminalTheme.small)
                .foregroundColor(TerminalTheme.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .terminalBorder()
    }
}
