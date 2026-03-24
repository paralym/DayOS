import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: TodoStore
    @State private var showAddTodo = false
    @State private var currentTime = Date()
    @State private var showBoot = true

    let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            TerminalTheme.background.ignoresSafeArea()

            if showBoot {
                BootScreenView {
                    withAnimation(.easeIn(duration: 0.4)) { showBoot = false }
                }
            } else {
                mainContent
            }

            ScanlineOverlay()
        }
        .onReceive(clockTimer) { _ in currentTime = Date() }
        .sheet(isPresented: $showAddTodo) {
            AddTodoView()
                .environmentObject(store)
        }
        .onAppear { styleWindow() }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            topBar
            Divider().background(TerminalTheme.border)
            statusLine
            Divider().background(TerminalTheme.border)
            TimelineView()
                .environmentObject(store)
            Divider().background(TerminalTheme.border)
            bottomBar
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 0) {
            // Logo pixel block
            HStack(spacing: 3) {
                ForEach([0, 1, 2, 3], id: \.self) { _ in
                    Rectangle()
                        .fill(TerminalTheme.primary)
                        .frame(width: 4, height: 4)
                        .glowEffect()
                }
            }
            .padding(.trailing, 8)

            Text("DAYOS")
                .font(TerminalTheme.header)
                .foregroundColor(TerminalTheme.primary)
                .glowEffect()
                .tracking(4)

            Text(" v1.0")
                .font(TerminalTheme.micro)
                .foregroundColor(TerminalTheme.primaryDim)

            Spacer()

            // Date
            Text(dateString)
                .font(TerminalTheme.small)
                .foregroundColor(TerminalTheme.primaryDim)
                .padding(.trailing, 12)

            // Clock
            Text(timeString)
                .font(TerminalTheme.header)
                .foregroundColor(TerminalTheme.cyan)
                .glowEffect(TerminalTheme.cyan)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(TerminalTheme.surface)
    }

    // MARK: - Status Line

    private var statusLine: some View {
        let todayTodos = store.todosForToday
        let active = todayTodos.filter { $0.isActive && !$0.isCompleted }.count
        let done = todayTodos.filter { $0.isCompleted }.count
        let total = todayTodos.count

        return HStack(spacing: 16) {
            Text(">_")
                .font(TerminalTheme.small)
                .foregroundColor(TerminalTheme.primaryDim)

            statChip("TASKS", "\(total)", TerminalTheme.primary)
            statChip("ACTIVE", "\(active)", TerminalTheme.cyan)
            statChip("DONE", "\(done)", TerminalTheme.amber)

            Spacer()

            if let next = nextTask {
                HStack(spacing: 4) {
                    Text("NEXT:")
                        .font(TerminalTheme.micro)
                        .foregroundColor(TerminalTheme.primaryDim)
                    Text(next.title.count > 20 ? String(next.title.uppercased().prefix(20)) + "…" : next.title.uppercased())
                        .font(TerminalTheme.micro)
                        .foregroundColor(next.priority.color)
                    Text("@\(next.startTime.timeString)")
                        .font(TerminalTheme.micro)
                        .foregroundColor(TerminalTheme.primaryDim)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(TerminalTheme.background)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            // Command hints
            HStack(spacing: 12) {
                cmdHint("[CLICK]", "select")
                cmdHint("[N]", "new task")
            }

            Spacer()

            HStack(spacing: 6) {
                BlinkingCursor(width: 6, height: 11)

                Button {
                    showAddTodo = true
                } label: {
                    HStack(spacing: 6) {
                        Text("+")
                            .font(TerminalTheme.header)
                        Text("NEW TASK")
                            .font(TerminalTheme.body)
                            .tracking(1)
                    }
                    .foregroundColor(TerminalTheme.background)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(TerminalTheme.primary)
                }
                .buttonStyle(.plain)
                .glowEffect()
                .keyboardShortcut("n", modifiers: [])
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(TerminalTheme.surface)
    }

    // MARK: - Helpers

    private func statChip(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(TerminalTheme.small)
                .foregroundColor(color)
                .glowEffect(color, radius: 2)
            Text(label)
                .font(TerminalTheme.micro)
                .foregroundColor(TerminalTheme.primaryDim)
        }
    }

    private func cmdHint(_ key: String, _ action: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(TerminalTheme.micro)
                .foregroundColor(TerminalTheme.primary.opacity(0.8))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .terminalBorder(TerminalTheme.border)
            Text(action)
                .font(TerminalTheme.micro)
                .foregroundColor(TerminalTheme.primaryDim)
        }
    }

    private var nextTask: Todo? {
        store.todosForToday
            .filter { $0.isFuture && !$0.isCompleted }
            .sorted { $0.startTime < $1.startTime }
            .first
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd EEE"
        return f.string(from: currentTime).uppercased()
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: currentTime)
    }

    // MARK: - Window styling

    private func styleWindow() {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first else { return }
            window.backgroundColor = NSColor(
                red: 0.02, green: 0.04, blue: 0.02, alpha: 1.0
            )
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
        }
    }
}

// MARK: - Boot Screen
struct BootScreenView: View {
    let onComplete: () -> Void

    @State private var lines: [String] = []
    @State private var cursor = true

    private let bootLines = [
        "DAYOS KERNEL v1.0.0 — INITIALIZING...",
        "LOADING TASK SCHEDULER.............. OK",
        "LOADING TIMELINE ENGINE............. OK",
        "LOADING NOTIFICATION DAEMON......... OK",
        "MOUNTING USER MEMORY................ OK",
        "SYNCHRONIZING CLOCK................. OK",
        "────────────────────────────────────────",
        "SYSTEM READY. WELCOME BACK.",
        "",
    ]

    var body: some View {
        ZStack {
            TerminalTheme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(TerminalTheme.small)
                        .foregroundColor(
                            line.contains("OK") ? TerminalTheme.cyan :
                            line.hasPrefix("─") ? TerminalTheme.border :
                            TerminalTheme.primary
                        )
                        .glowEffect(radius: 2)
                }
                if lines.count < bootLines.count {
                    BlinkingCursor()
                }
                Spacer()
            }
            .padding(30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { runBoot() }
    }

    private func runBoot() {
        for (i, line) in bootLines.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) {
                lines.append(line)
                if i == bootLines.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onComplete()
                    }
                }
            }
        }
    }
}
