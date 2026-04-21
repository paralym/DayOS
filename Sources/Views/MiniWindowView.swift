import SwiftUI

// MARK: - Height preference key

private struct MiniHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - View

struct MiniWindowView: View {
    @EnvironmentObject var todoStore: TodoStore
    @State private var now = Date()

    private let width: CGFloat = 220
    private let corner: CGFloat = 10
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    /// Task currently in its time window (running or paused), not completed
    private var currentTask: Todo? {
        todoStore.todosForToday.first { $0.isInTimeWindow && !$0.isCompleted }
    }

    private var upcoming: Todo? {
        todoStore.todosForToday
            .filter { $0.isFuture && !$0.isCompleted }
            .sorted { $0.startTime < $1.startTime }
            .first
    }

    var body: some View {
        VStack(spacing: 0) {
            mainRow
                .padding(.horizontal, 12)
                .padding(.top, 9)
                .padding(.bottom, currentTask != nil ? 6 : 9)

            if let task = currentTask {
                progressBar(for: task)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .frame(width: width)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: MiniHeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(MiniHeightKey.self) { h in
            DispatchQueue.main.async { MiniWindowManager.shared.updateHeight(h) }
        }
        .background(
            RoundedRectangle(cornerRadius: corner)
                .fill(TerminalTheme.surface.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: corner)
                .stroke(TerminalTheme.border.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 3)
        .onTapGesture {
            MiniWindowManager.shared.toggleMainWindow()
        }
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    MiniWindowManager.shared.dragChanged(translation: value.translation)
                }
                .onEnded { _ in MiniWindowManager.shared.dragEnded() }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 4)
                .onChanged { _ in MiniWindowManager.shared.dragBegan() }
        )
        .onReceive(timer) { _ in now = Date() }
    }

    // MARK: - Main row

    private var mainRow: some View {
        Group {
            if let task = currentTask {
                HStack(spacing: 6) {
                    Text(task.isPaused ? "⏸" : "►")
                        .font(TerminalTheme.small)
                        .foregroundColor(task.isPaused ? TerminalTheme.primaryDim : task.priority.color)
                        .glowEffect(task.isPaused ? TerminalTheme.primaryDim : task.priority.color, radius: 2)
                    Text(task.title)
                        .font(TerminalTheme.small)
                        .foregroundColor(task.isPaused ? TerminalTheme.primaryDim : TerminalTheme.primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Button {
                        todoStore.togglePause(id: task.id)
                    } label: {
                        Text(task.isPaused ? "▶" : "⏸")
                            .font(TerminalTheme.micro)
                            .foregroundColor(task.isPaused ? TerminalTheme.cyan : TerminalTheme.primaryDim)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(TerminalTheme.border.opacity(0.2))
                    }
                    .buttonStyle(.plain)
                    Text(remainingTime(for: task))
                        .font(TerminalTheme.small)
                        .foregroundColor(TerminalTheme.primaryDim)
                        .monospacedDigit()
                }
            } else if let next = upcoming {
                HStack(spacing: 6) {
                    Text("·")
                        .font(TerminalTheme.small)
                        .foregroundColor(TerminalTheme.amber)
                    Text(next.title)
                        .font(TerminalTheme.small)
                        .foregroundColor(TerminalTheme.primaryDim)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("in \(minutesUntil(next.startTime))m")
                        .font(TerminalTheme.small)
                        .foregroundColor(TerminalTheme.primaryDim.opacity(0.6))
                        .monospacedDigit()
                }
            } else {
                HStack(spacing: 6) {
                    Text("~")
                        .font(TerminalTheme.small)
                        .foregroundColor(TerminalTheme.primaryDim)
                    Text("free")
                        .font(TerminalTheme.small)
                        .foregroundColor(TerminalTheme.primaryDim.opacity(0.5))
                    Spacer(minLength: 4)
                    Text(timeString)
                        .font(TerminalTheme.small)
                        .foregroundColor(TerminalTheme.cyan.opacity(0.5))
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Progress bar

    private func progressBar(for task: Todo) -> some View {
        let barColor = task.isPaused ? TerminalTheme.primaryDim.opacity(0.5) : task.priority.color.opacity(0.8)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(TerminalTheme.border.opacity(0.35))
                    .frame(height: 3)
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor)
                    .frame(width: max(4, geo.size.width * task.progress), height: 3)
                    .glowEffect(task.isPaused ? TerminalTheme.primaryDim : task.priority.color, radius: 1.5)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Helpers

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: now)
    }

    private func remainingTime(for todo: Todo) -> String {
        let mins = Int(todo.endTime.timeIntervalSince(now) / 60)
        guard mins > 0 else { return "done" }
        if mins < 60 { return "\(mins)m" }
        let h = mins / 60, m = mins % 60
        return m == 0 ? "\(h)h" : "\(h)h\(m)m"
    }

    private func minutesUntil(_ date: Date) -> Int {
        max(0, Int(date.timeIntervalSince(now) / 60))
    }
}
