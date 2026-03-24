import SwiftUI

struct NotesPanelView: View {
    @EnvironmentObject var noteStore: NoteStore
    @EnvironmentObject var todoStore: TodoStore
    @Binding var isCollapsed: Bool

    @State private var viewMode: ViewMode = .raw
    @State private var editingText: String = ""
    @State private var showAddConfirm: UUID? = nil

    enum ViewMode { case raw, agent }

    var body: some View {
        HStack(spacing: 0) {
            if !isCollapsed {
                VStack(spacing: 0) {
                    panelHeader
                    Divider().background(TerminalTheme.border)
                    incompleteBanner
                    modeToggle
                    Divider().background(TerminalTheme.border)
                    noteContent
                    if !activeSuggestions.isEmpty {
                        Divider().background(TerminalTheme.border)
                        suggestionsPanel
                    }
                }
                .frame(width: 240)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            // Collapse handle
            collapseHandle
        }
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack(spacing: 6) {
            Text("> NOTE")
                .font(TerminalTheme.header)
                .foregroundColor(TerminalTheme.primary)
                .glowEffect()
            Text(todayLabel)
                .font(TerminalTheme.micro)
                .foregroundColor(TerminalTheme.primaryDim)
            Spacer()
            agentStatusDot
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(TerminalTheme.surface)
    }

    private var agentStatusDot: some View {
        Group {
            switch noteStore.processingState {
            case .processing:
                HStack(spacing: 4) {
                    Circle().fill(TerminalTheme.amber).frame(width: 5, height: 5)
                        .glowEffect(TerminalTheme.amber)
                    Text("THINKING")
                        .font(TerminalTheme.micro)
                        .foregroundColor(TerminalTheme.amber)
                }
            case .updated:
                HStack(spacing: 4) {
                    Circle().fill(TerminalTheme.cyan).frame(width: 5, height: 5)
                        .glowEffect(TerminalTheme.cyan)
                    Text("SYNCED")
                        .font(TerminalTheme.micro)
                        .foregroundColor(TerminalTheme.cyan)
                }
            case .error:
                Circle().fill(TerminalTheme.red).frame(width: 5, height: 5)
                    .glowEffect(TerminalTheme.red)
            case .idle:
                Circle().fill(TerminalTheme.primaryDim).frame(width: 5, height: 5)
            }
        }
    }

    // MARK: - Incomplete banner

    @ViewBuilder
    private var incompleteBanner: some View {
        let old = todoStore.incompletePreviousTodos
        if !old.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("⚠")
                        .font(TerminalTheme.small)
                        .foregroundColor(TerminalTheme.amber)
                    Text("\(old.count) UNFINISHED FROM BEFORE")
                        .font(TerminalTheme.micro)
                        .foregroundColor(TerminalTheme.amber)
                        .glowEffect(TerminalTheme.amber, radius: 2)
                }
                ForEach(old.prefix(3)) { todo in
                    HStack(spacing: 4) {
                        Text("·")
                            .font(TerminalTheme.micro)
                            .foregroundColor(TerminalTheme.amber.opacity(0.6))
                        Text(todo.title.uppercased())
                            .font(TerminalTheme.micro)
                            .foregroundColor(TerminalTheme.amber.opacity(0.8))
                            .lineLimit(1)
                        Spacer()
                        Button {
                            rescheduleToday(todo)
                        } label: {
                            Text("[→]")
                                .font(TerminalTheme.micro)
                                .foregroundColor(TerminalTheme.amber)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if old.count > 3 {
                    Text("  + \(old.count - 3) more...")
                        .font(TerminalTheme.micro)
                        .foregroundColor(TerminalTheme.amber.opacity(0.5))
                }
            }
            .padding(8)
            .background(TerminalTheme.amber.opacity(0.06))
            .terminalBorder(TerminalTheme.amber.opacity(0.3))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)

            Divider().background(TerminalTheme.border)
        }
    }

    // MARK: - Mode toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeButton("RAW", .raw)
            modeButton("AGENT", .agent)
            Spacer()
            // Agent processing status in micro text
            if case .processing = noteStore.processingState {
                Text("processing...")
                    .font(TerminalTheme.micro)
                    .foregroundColor(TerminalTheme.amber)
                    .padding(.trailing, 8)
            } else if !ClaudeAPIManager.shared.hasKey {
                Text("no key")
                    .font(TerminalTheme.micro)
                    .foregroundColor(TerminalTheme.red.opacity(0.7))
                    .padding(.trailing, 8)
            }
        }
        .background(TerminalTheme.surface)
    }

    private func modeButton(_ label: String, _ mode: ViewMode) -> some View {
        Button { viewMode = mode } label: {
            Text(label)
                .font(TerminalTheme.small)
                .foregroundColor(viewMode == mode ? TerminalTheme.background : TerminalTheme.primaryDim)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(viewMode == mode ? TerminalTheme.primary : Color.clear)
        }
        .buttonStyle(.plain)
        .glowEffect(radius: viewMode == mode ? 2 : 0)
    }

    // MARK: - Note content

    @ViewBuilder
    private var noteContent: some View {
        switch viewMode {
        case .raw:
            rawEditor
        case .agent:
            agentView
        }
    }

    private var rawEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $editingText)
                .font(TerminalTheme.small)
                .foregroundColor(TerminalTheme.primary)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(8)
                .onChange(of: editingText) { newVal in
                    noteStore.updateRawContent(newVal)
                }

            if editingText.isEmpty {
                Text("dump your thoughts here...\n\n> team meeting 10am\n> finish report (urgent)\n> call alice re: contract")
                    .font(TerminalTheme.small)
                    .foregroundColor(TerminalTheme.primaryDim.opacity(0.35))
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var agentView: some View {
        if noteStore.todayNote.organizedContent.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                if !ClaudeAPIManager.shared.hasKey {
                    Text("NO API KEY\nConfigure in ⚡ AI settings")
                        .font(TerminalTheme.small)
                        .foregroundColor(TerminalTheme.red.opacity(0.7))
                        .multilineTextAlignment(.center)
                } else if noteStore.todayNote.rawContent.isEmpty {
                    Text("Start writing notes\nAgent will organize automatically")
                        .font(TerminalTheme.small)
                        .foregroundColor(TerminalTheme.primaryDim.opacity(0.5))
                        .multilineTextAlignment(.center)
                } else {
                    BlinkingCursor(color: TerminalTheme.cyan)
                    Text("Waiting for agent...")
                        .font(TerminalTheme.small)
                        .foregroundColor(TerminalTheme.primaryDim)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                Text(noteStore.todayNote.organizedContent)
                    .font(TerminalTheme.small)
                    .foregroundColor(TerminalTheme.cyan.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
        }
    }

    // MARK: - Suggestions

    private var activeSuggestions: [AgentSuggestion] {
        noteStore.todayNote.suggestions.filter { !$0.isDismissed }
    }

    private var suggestionsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("AGENT SUGGESTS")
                    .font(TerminalTheme.micro)
                    .foregroundColor(TerminalTheme.cyan)
                    .tracking(1)
                    .glowEffect(TerminalTheme.cyan, radius: 2)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(TerminalTheme.surface)

            ForEach(activeSuggestions) { sug in
                suggestionRow(sug)
                Divider().background(TerminalTheme.borderDim)
            }
        }
    }

    private func suggestionRow(_ sug: AgentSuggestion) -> some View {
        let col = sug.priority.color
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(sug.priority.symbol)
                    .font(TerminalTheme.micro)
                    .foregroundColor(col)
                Text(sug.title.uppercased())
                    .font(TerminalTheme.micro)
                    .foregroundColor(col)
                    .glowEffect(col, radius: 2)
                    .lineLimit(1)
                Spacer()
                // Add button
                Button {
                    addSuggestionToTimeline(sug)
                } label: {
                    Text("[+]")
                        .font(TerminalTheme.micro)
                        .foregroundColor(TerminalTheme.primary)
                }
                .buttonStyle(.plain)
                .glowEffect(radius: 2)
                // Dismiss
                Button {
                    noteStore.dismissSuggestion(id: sug.id)
                } label: {
                    Text("[✕]")
                        .font(TerminalTheme.micro)
                        .foregroundColor(TerminalTheme.primaryDim)
                }
                .buttonStyle(.plain)
            }
            Text("~\(sug.estimatedMinutes)m · \(sug.reason)")
                .font(TerminalTheme.micro)
                .foregroundColor(col.opacity(0.5))
                .lineLimit(2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(col.opacity(0.04))
    }

    // MARK: - Collapse handle

    private var collapseHandle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCollapsed.toggle()
            }
        } label: {
            VStack {
                Spacer()
                Text(isCollapsed ? "›" : "‹")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(TerminalTheme.primaryDim)
                Spacer()
            }
            .frame(width: 16)
            .background(TerminalTheme.surface)
            .terminalBorder(TerminalTheme.borderDim)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var todayLabel: String {
        let df = DateFormatter()
        df.dateFormat = "MM/dd"
        return df.string(from: Date())
    }

    private func addSuggestionToTimeline(_ sug: AgentSuggestion) {
        let now = Date()
        let cal = Calendar.current
        // Schedule at the next free-ish slot after current time (round up to next half hour)
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let mins = comps.minute ?? 0
        comps.minute = mins < 30 ? 30 : 0
        if mins >= 30 { comps.hour = (comps.hour ?? 0) + 1 }
        comps.second = 0
        let start = cal.date(from: comps) ?? now
        let end   = start.addingTimeInterval(Double(sug.estimatedMinutes) * 60)

        let todo = Todo(title: sug.title, startTime: start, endTime: end,
                       notes: sug.reason, priority: sug.priority)
        todoStore.addTodo(todo)
        noteStore.markSuggestionAdded(id: sug.id)
    }

    private func rescheduleToday(_ todo: Todo) {
        var updated = todo
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let origDuration = todo.duration
        // Preserve time-of-day but move to today
        let origComps = cal.dateComponents([.hour, .minute], from: todo.startTime)
        if let newStart = cal.date(bySettingHour: origComps.hour ?? 9,
                                   minute: origComps.minute ?? 0,
                                   second: 0, of: todayStart) {
            updated.startTime = newStart
            updated.endTime   = newStart.addingTimeInterval(origDuration)
            todoStore.updateTodo(updated)
        }
    }
}

// MARK: - TodoStore extension

extension TodoStore {
    var incompletePreviousTodos: [Todo] {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return todos.filter { !$0.isCompleted && $0.startTime < todayStart }
    }
}
