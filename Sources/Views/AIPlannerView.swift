import SwiftUI

struct AIPlannerView: View {
    @EnvironmentObject var store: TodoStore
    @StateObject private var api = ClaudeAPIManager.shared
    @Environment(\.dismiss) var dismiss

    // UI state
    @State private var inputText: String = ""
    @State private var phase: Phase = .input
    @State private var plannedTasks: [AIScheduledTask] = []
    @State private var reasoning: String = ""
    @State private var errorMsg: String? = nil
    @State private var showAPIKeyEntry = false
    @State private var typingText: String = ""
    @State private var typingTimer: Timer? = nil

    enum Phase { case input, loading, preview }

    var body: some View {
        ZStack {
            TerminalTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                Divider().background(TerminalTheme.border)

                switch phase {
                case .input:   inputPhase
                case .loading: loadingPhase
                case .preview: previewPhase
                }
            }

            ScanlineOverlay()
        }
        .frame(width: 500, height: 580)
        .sheet(isPresented: $showAPIKeyEntry) {
            APIKeyView()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            HStack(spacing: 6) {
                Text("⚡")
                Text("AI TASK PLANNER")
                    .font(TerminalTheme.header)
                    .foregroundColor(TerminalTheme.cyan)
                    .glowEffect(TerminalTheme.cyan)
                    .tracking(2)
            }
            Spacer()
            // API key status
            Button {
                showAPIKeyEntry = true
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(api.hasKey ? TerminalTheme.primary : TerminalTheme.red)
                        .frame(width: 6, height: 6)
                        .glowEffect(api.hasKey ? TerminalTheme.primary : TerminalTheme.red)
                    Text(api.hasKey ? "CLAUDE READY" : "NO API KEY")
                        .font(TerminalTheme.micro)
                        .foregroundColor(api.hasKey ? TerminalTheme.primaryDim : TerminalTheme.red)
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)

            Button { dismiss() } label: {
                Text("[ ✕ ]")
                    .font(TerminalTheme.body)
                    .foregroundColor(TerminalTheme.primaryDim)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(TerminalTheme.surface)
    }

    // MARK: - Input Phase

    private var inputPhase: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Instructions
            VStack(alignment: .leading, spacing: 4) {
                Text("> DUMP YOUR TASKS BELOW")
                    .font(TerminalTheme.small)
                    .foregroundColor(TerminalTheme.primaryDim)
                    .padding(.bottom, 2)
                Text("  Free-form is fine. Examples:")
                    .font(TerminalTheme.micro)
                    .foregroundColor(TerminalTheme.primaryDim.opacity(0.7))
                Text("  · write quarterly report (urgent, ~2h)")
                    .font(TerminalTheme.micro)
                    .foregroundColor(TerminalTheme.primaryDim.opacity(0.5))
                Text("  · team standup at 10am")
                    .font(TerminalTheme.micro)
                    .foregroundColor(TerminalTheme.primaryDim.opacity(0.5))
                Text("  · review Alice's PR, lunch, prep slides")
                    .font(TerminalTheme.micro)
                    .foregroundColor(TerminalTheme.primaryDim.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Text area
            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .font(TerminalTheme.body)
                    .foregroundColor(TerminalTheme.primary)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(10)

                if inputText.isEmpty {
                    Text("start typing...")
                        .font(TerminalTheme.body)
                        .foregroundColor(TerminalTheme.primaryDim.opacity(0.4))
                        .padding(14)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .terminalBorder(TerminalTheme.border)
            .padding(.horizontal, 16)

            if let err = errorMsg {
                Text("ERR: \(err)")
                    .font(TerminalTheme.small)
                    .foregroundColor(TerminalTheme.red)
                    .glowEffect(TerminalTheme.red)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            Divider().background(TerminalTheme.border).padding(.top, 12)

            // Bottom action bar
            HStack {
                Button { dismiss() } label: {
                    Text("[ CANCEL ]")
                        .font(TerminalTheme.body)
                        .foregroundColor(TerminalTheme.primaryDim)
                }
                .buttonStyle(.plain)

                Spacer()

                Button { runPlanner() } label: {
                    HStack(spacing: 6) {
                        Text("⚡")
                        Text("PLAN MY DAY")
                            .tracking(1)
                    }
                    .font(TerminalTheme.body)
                    .foregroundColor(TerminalTheme.background)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(TerminalTheme.cyan)
                }
                .buttonStyle(.plain)
                .glowEffect(TerminalTheme.cyan)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !api.hasKey)
                .opacity((inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !api.hasKey) ? 0.4 : 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(TerminalTheme.surface)
        }
    }

    // MARK: - Loading Phase

    private var loadingPhase: some View {
        VStack(spacing: 20) {
            Spacer()

            // Animated terminal lines
            VStack(alignment: .leading, spacing: 6) {
                Text(typingText)
                    .font(TerminalTheme.small)
                    .foregroundColor(TerminalTheme.cyan)
                    .glowEffect(TerminalTheme.cyan, radius: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                BlinkingCursor(color: TerminalTheme.cyan)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .terminalBorder(TerminalTheme.border)
            .padding(.horizontal, 24)

            Text("Analyzing your tasks and building optimal schedule...")
                .font(TerminalTheme.micro)
                .foregroundColor(TerminalTheme.primaryDim)

            Spacer()
        }
        .onAppear { startTypingAnimation() }
        .onDisappear { typingTimer?.invalidate() }
    }

    // MARK: - Preview Phase

    private var previewPhase: some View {
        VStack(spacing: 0) {
            // Reasoning banner
            if !reasoning.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text("CLAUDE:")
                            .font(TerminalTheme.micro)
                            .foregroundColor(TerminalTheme.cyan)
                        Text(reasoning)
                            .font(TerminalTheme.micro)
                            .foregroundColor(TerminalTheme.primaryDim)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .background(TerminalTheme.surface)
                Divider().background(TerminalTheme.border)
            }

            // Task list header
            HStack {
                Text("> PROPOSED SCHEDULE  [\(plannedTasks.count) TASKS]")
                    .font(TerminalTheme.small)
                    .foregroundColor(TerminalTheme.primaryDim)
                Spacer()
                Button {
                    let all = plannedTasks.allSatisfy { $0.isSelected }
                    for i in plannedTasks.indices { plannedTasks[i].isSelected = !all }
                } label: {
                    Text(plannedTasks.allSatisfy { $0.isSelected } ? "DESELECT ALL" : "SELECT ALL")
                        .font(TerminalTheme.micro)
                        .foregroundColor(TerminalTheme.primaryDim)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider().background(TerminalTheme.border)

            // Task rows
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(plannedTasks.indices, id: \.self) { i in
                        plannedTaskRow(index: i)
                        Divider().background(TerminalTheme.borderDim)
                    }
                }
            }

            Divider().background(TerminalTheme.border)

            // Actions
            HStack {
                Button {
                    phase = .input
                    errorMsg = nil
                } label: {
                    Text("[ ◀ REDO ]")
                        .font(TerminalTheme.body)
                        .foregroundColor(TerminalTheme.primaryDim)
                }
                .buttonStyle(.plain)

                Spacer()

                let selected = plannedTasks.filter { $0.isSelected }.count
                Button {
                    commitTasks()
                } label: {
                    Text("[ ADD \(selected) TASKS ▶ ]")
                        .font(TerminalTheme.body)
                        .foregroundColor(TerminalTheme.background)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(selected > 0 ? TerminalTheme.primary : TerminalTheme.primaryDim)
                }
                .buttonStyle(.plain)
                .glowEffect()
                .disabled(selected == 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(TerminalTheme.surface)
        }
    }

    private func plannedTaskRow(index: Int) -> some View {
        let task = plannedTasks[index]
        let col = task.priority.color

        return HStack(spacing: 10) {
            // Checkbox
            Button {
                plannedTasks[index].isSelected.toggle()
            } label: {
                Text(task.isSelected ? "[✓]" : "[ ]")
                    .font(TerminalTheme.small)
                    .foregroundColor(task.isSelected ? col : TerminalTheme.primaryDim)
                    .glowEffect(col, radius: task.isSelected ? 3 : 0)
            }
            .buttonStyle(.plain)

            // Time
            Text("\(task.startTime)–\(task.endTime)")
                .font(TerminalTheme.micro)
                .foregroundColor(TerminalTheme.primaryDim)
                .frame(width: 80, alignment: .leading)

            // Title
            Text(task.title.uppercased())
                .font(TerminalTheme.small)
                .foregroundColor(task.isSelected ? col : col.opacity(0.4))
                .glowEffect(col, radius: task.isSelected ? 2 : 0)
                .lineLimit(1)

            Spacer()

            // Priority badge
            Text("[\(task.priority.rawValue)]")
                .font(TerminalTheme.micro)
                .foregroundColor(col.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(task.isSelected ? col.opacity(0.04) : Color.clear)
    }

    // MARK: - Logic

    private func runPlanner() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        errorMsg = nil
        phase = .loading

        Task {
            do {
                let result = try await api.planTasks(input: inputText)
                await MainActor.run {
                    plannedTasks = result.tasks
                    reasoning = result.reasoning
                    phase = .preview
                }
            } catch {
                await MainActor.run {
                    errorMsg = error.localizedDescription
                    phase = .input
                }
            }
        }
    }

    private func commitTasks() {
        let selected = plannedTasks.filter { $0.isSelected }
        for aiTask in selected {
            if let todo = aiTask.toTodo() {
                store.addTodo(todo)
            }
        }
        dismiss()
    }

    private func startTypingAnimation() {
        let messages = [
            "> PARSING TASK LIST...",
            "> ANALYZING DEPENDENCIES...",
            "> ESTIMATING DURATIONS...",
            "> OPTIMIZING SCHEDULE...",
            "> APPLYING PRIORITIES...",
            "> FINALIZING TIMELINE...",
        ]
        var idx = 0
        typingText = messages[0]
        typingTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            idx = (idx + 1) % messages.count
            typingText = messages[idx]
        }
    }
}

// MARK: - API Key Entry View
struct APIKeyView: View {
    @StateObject private var api = ClaudeAPIManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var keyInput: String = ""
    @State private var showKey = false

    var body: some View {
        ZStack {
            TerminalTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("> ANTHROPIC API KEY")
                        .font(TerminalTheme.header)
                        .foregroundColor(TerminalTheme.amber)
                        .glowEffect(TerminalTheme.amber)
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
                    Text("Get your key from: console.anthropic.com")
                        .font(TerminalTheme.micro)
                        .foregroundColor(TerminalTheme.primaryDim)

                    HStack(spacing: 6) {
                        Text(">")
                            .font(TerminalTheme.body)
                            .foregroundColor(TerminalTheme.primaryDim)
                        if showKey {
                            TextField("sk-ant-...", text: $keyInput)
                                .textFieldStyle(.plain)
                                .font(TerminalTheme.body)
                                .foregroundColor(TerminalTheme.amber)
                        } else {
                            SecureField("sk-ant-...", text: $keyInput)
                                .textFieldStyle(.plain)
                                .font(TerminalTheme.body)
                                .foregroundColor(TerminalTheme.amber)
                        }
                        Button {
                            showKey.toggle()
                        } label: {
                            Text(showKey ? "[HIDE]" : "[SHOW]")
                                .font(TerminalTheme.micro)
                                .foregroundColor(TerminalTheme.primaryDim)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .terminalBorder(TerminalTheme.amber.opacity(0.5))

                    Text("⚠  Key is stored locally in UserDefaults. Never share it.")
                        .font(TerminalTheme.micro)
                        .foregroundColor(TerminalTheme.amber.opacity(0.7))
                }
                .padding(20)

                Divider().background(TerminalTheme.border)

                HStack {
                    if api.hasKey {
                        Button {
                            api.apiKey = ""
                            keyInput = ""
                        } label: {
                            Text("[ CLEAR KEY ]")
                                .font(TerminalTheme.body)
                                .foregroundColor(TerminalTheme.red)
                        }
                        .buttonStyle(.plain)
                        .glowEffect(TerminalTheme.red)
                    }
                    Spacer()
                    Button {
                        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { api.apiKey = trimmed }
                        dismiss()
                    } label: {
                        Text("[ SAVE ▶ ]")
                            .font(TerminalTheme.body)
                            .foregroundColor(TerminalTheme.background)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(TerminalTheme.amber)
                    }
                    .buttonStyle(.plain)
                    .glowEffect(TerminalTheme.amber)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(TerminalTheme.surface)
            }
        }
        .frame(width: 400, height: 250)
        .onAppear { keyInput = api.apiKey }
    }
}
