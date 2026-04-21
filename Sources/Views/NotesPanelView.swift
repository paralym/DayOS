import SwiftUI

struct NotesPanelView: View {
    @EnvironmentObject var noteStore: NoteStore
    @EnvironmentObject var todoStore: TodoStore
    @Binding var isCollapsed: Bool

    @State private var viewMode: ViewMode = .raw
    @State private var editingText: String = ""
    @State private var editingAgentText: String = ""
    @State private var hasInitialized = false
    @State private var expandedSuggestionId: UUID? = nil
    @State private var editedStartTimes: [UUID: Date] = [:]
    @State private var editedEndTimes: [UUID: Date] = [:]

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
        .onAppear {
            if !hasInitialized {
                editingText = noteStore.todayNote.rawContent
                hasInitialized = true
            }
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
                    noteStore.updateRawContent(newVal, todos: todoStore.todosForToday)
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
            ZStack(alignment: .topLeading) {
                TextEditor(text: $editingAgentText)
                    .font(TerminalTheme.small)
                    .foregroundColor(TerminalTheme.cyan.opacity(0.9))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(8)
                    .onChange(of: editingAgentText) { newVal in
                        noteStore.updateOrganizedContent(newVal)
                    }
                    .onChange(of: noteStore.todayNote.organizedContent) { newVal in
                        // Sync when agent rewrites content (avoid loop if user is editing)
                        if newVal != editingAgentText {
                            editingAgentText = newVal
                        }
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                editingAgentText = noteStore.todayNote.organizedContent
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
        let isExpanded = expandedSuggestionId == sug.id
        let start = editedStartTimes[sug.id] ?? proposedStart(for: sug)
        let end   = editedEndTimes[sug.id] ?? start.addingTimeInterval(Double(sug.estimatedMinutes) * 60)

        return VStack(alignment: .leading, spacing: 0) {
            // ── Collapsed header row (always visible) ──
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    expandedSuggestionId = isExpanded ? nil : sug.id
                    if editedStartTimes[sug.id] == nil {
                        let s = proposedStart(for: sug)
                        editedStartTimes[sug.id] = s
                        editedEndTimes[sug.id] = s.addingTimeInterval(Double(sug.estimatedMinutes) * 60)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(isExpanded ? "▼" : "▶")
                        .font(TerminalTheme.micro)
                        .foregroundColor(col.opacity(0.6))
                    Text(sug.priority.symbol)
                        .font(TerminalTheme.micro)
                        .foregroundColor(col)
                    Text(sug.title.uppercased())
                        .font(TerminalTheme.micro)
                        .foregroundColor(col)
                        .glowEffect(col, radius: 2)
                        .lineLimit(1)
                    Spacer()
                    Text("~\(sug.estimatedMinutes)m")
                        .font(TerminalTheme.micro)
                        .foregroundColor(col.opacity(0.5))
                    Button {
                        noteStore.dismissSuggestion(id: sug.id)
                    } label: {
                        Text("[✕]")
                            .font(TerminalTheme.micro)
                            .foregroundColor(TerminalTheme.primaryDim)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(isExpanded ? col.opacity(0.10) : col.opacity(0.04))
            }
            .buttonStyle(.plain)

            // ── Expanded detail ──
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Start picker
                    HStack(spacing: 4) {
                        Text("START")
                            .font(TerminalTheme.micro)
                            .foregroundColor(TerminalTheme.primaryDim)
                            .frame(width: 34, alignment: .leading)
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { editedStartTimes[sug.id] ?? start },
                                set: { newStart in
                                    // Keep duration when start changes
                                    let dur = end.timeIntervalSince(start)
                                    editedStartTimes[sug.id] = newStart
                                    editedEndTimes[sug.id] = newStart.addingTimeInterval(dur)
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.field)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .accentColor(col)
                        .font(TerminalTheme.small)
                    }

                    // End picker
                    HStack(spacing: 4) {
                        Text("END")
                            .font(TerminalTheme.micro)
                            .foregroundColor(TerminalTheme.primaryDim)
                            .frame(width: 34, alignment: .leading)
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { editedEndTimes[sug.id] ?? end },
                                set: { editedEndTimes[sug.id] = $0 }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.field)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .accentColor(col)
                        .font(TerminalTheme.small)
                    }

                    // Reason
                    Text(sug.reason)
                        .font(TerminalTheme.micro)
                        .foregroundColor(col.opacity(0.55))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    // Confirm button
                    Button {
                        addSuggestionWithTime(sug, start: editedStartTimes[sug.id] ?? start,
                                              end: editedEndTimes[sug.id] ?? end)
                        expandedSuggestionId = nil
                    } label: {
                        Text("+ ADD TO TIMELINE")
                            .font(TerminalTheme.micro)
                            .tracking(1)
                            .foregroundColor(TerminalTheme.background)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(col)
                    }
                    .buttonStyle(.plain)
                    .glowEffect(col, radius: 2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(col.opacity(0.06))
            }
        }
    }

    // Allow using .let on value types for inline binding
    private func addSuggestionWithTime(_ sug: AgentSuggestion, start: Date, end: Date) {
        let todo = Todo(title: sug.title, startTime: start, endTime: end,
                       notes: sug.reason, priority: sug.priority)
        todoStore.addTodo(todo)
        noteStore.markSuggestionAdded(id: sug.id)
        editedStartTimes.removeValue(forKey: sug.id)
        editedEndTimes.removeValue(forKey: sug.id)
    }

    /// Computes the next available half-hour slot, stacking suggestions sequentially
    private func proposedStart(for sug: AgentSuggestion) -> Date {
        let cal = Calendar.current
        let now = Date()
        // Round current time up to next 30-min boundary
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let m = comps.minute ?? 0
        if m < 30 { comps.minute = 30 } else { comps.minute = 0; comps.hour = (comps.hour ?? 0) + 1 }
        comps.second = 0
        var base = cal.date(from: comps) ?? now

        // Push base past any existing todo that overlaps
        let todayTodos = todoStore.todosForToday.filter { !$0.isCompleted }
        for _ in 0..<48 { // max 24h scan in 30min steps
            let candidate = base
            let candidateEnd = candidate.addingTimeInterval(Double(sug.estimatedMinutes) * 60)
            let conflicts = todayTodos.contains { t in
                t.startTime < candidateEnd && t.endTime > candidate
            }
            if !conflicts { break }
            base = base.addingTimeInterval(1800)
        }

        // Also stack after previously expanded suggestions
        let active = activeSuggestions
        if let idx = active.firstIndex(where: { $0.id == sug.id }), idx > 0 {
            var cursor = base
            for i in 0..<idx {
                let prev = active[i]
                let prevStart = editedStartTimes[prev.id] ?? cursor
                cursor = prevStart.addingTimeInterval(Double(prev.estimatedMinutes) * 60 + 900) // +15min buffer
            }
            base = max(base, cursor)
        }
        return base
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
