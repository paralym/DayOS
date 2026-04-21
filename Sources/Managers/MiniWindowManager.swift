import AppKit
import QuartzCore
import SwiftUI

// Clips hosted SwiftUI content to a rounded rect so no corner background leaks.
private class MaskedHostingView<Content: View>: NSHostingView<Content> {
    private let corner: CGFloat

    init(rootView: Content, cornerRadius: CGFloat) {
        self.corner = cornerRadius
        super.init(rootView: rootView)
        wantsLayer = true
        layer?.backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @available(*, unavailable)
    required init(rootView: Content) { fatalError() }

    override func layout() {
        super.layout()
        let mask = CAShapeLayer()
        mask.path = CGPath(
            roundedRect: bounds,
            cornerWidth: corner,
            cornerHeight: corner,
            transform: nil
        )
        layer?.mask = mask
        layer?.backgroundColor = .clear
    }
}

class MiniWindowManager: NSObject {
    static let shared = MiniWindowManager()

    private var panel: NSPanel?
    private var isFirstLayout = true
    private var dragStartOrigin: CGPoint?
    let panelWidth: CGFloat = 200
    private let cornerRadius: CGFloat = 10
    private let defaultsKey = "miniWindowPinned"

    /// true = floating on top; false = desktop widget level
    var isPinned: Bool {
        get { UserDefaults.standard.bool(forKey: defaultsKey) == false ? true : UserDefaults.standard.bool(forKey: defaultsKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultsKey)
            applyLevel()
        }
    }

    func setup(todoStore: TodoStore) {
        guard panel == nil else { return }

        // Default to pinned (floating) if never set
        if UserDefaults.standard.object(forKey: defaultsKey) == nil {
            UserDefaults.standard.set(true, forKey: defaultsKey)
        }

        let content = MiniWindowView().environmentObject(todoStore)
        let hosting = MaskedHostingView(rootView: content, cornerRadius: cornerRadius)
        hosting.autoresizingMask = []

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: 38),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.contentView = hosting

        self.panel = panel
        applyLevel()
        positionTopRight(panel)
        panel.orderFront(nil)

        // Right-click context menu
        let menu = NSMenu()
        menu.addItem(withTitle: "打开 DayOS", action: #selector(menuOpenApp), keyEquivalent: "")
            .target = self
        menu.addItem(NSMenuItem.separator())
        let pinItem = NSMenuItem(title: isPinned ? "✓ 窗口置顶" : "  窗口置顶", action: #selector(menuTogglePin), keyEquivalent: "")
        pinItem.target = self
        pinItem.tag = 1
        menu.addItem(pinItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "退出 DayOS", action: #selector(menuQuit), keyEquivalent: "")
            .target = self
        menu.delegate = self
        panel.contentView?.menu = menu
    }

    /// Called by MiniWindowView via preference key when its natural height changes.
    func updateHeight(_ height: CGFloat) {
        guard let panel = panel, height > 0 else { return }
        var frame = panel.frame
        let topY = frame.maxY
        frame.origin.y = topY - height
        frame.size = CGSize(width: panelWidth, height: height)

        if isFirstLayout {
            panel.setFrame(frame, display: true)
            isFirstLayout = false
        } else {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(frame, display: true)
            }
        }
    }

    // MARK: - Window level

    private func applyLevel() {
        guard let panel = panel else { return }
        if isPinned {
            panel.level = .floating
        } else {
            // Desktop widget level — below normal windows, above desktop icons
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        }
    }

    // MARK: - Drag

    func dragBegan() {
        dragStartOrigin = panel?.frame.origin
    }

    func dragChanged(translation: CGSize) {
        guard let panel = panel, let origin = dragStartOrigin else { return }
        panel.setFrameOrigin(NSPoint(
            x: origin.x + translation.width,
            y: origin.y - translation.height
        ))
    }

    func dragEnded() {
        dragStartOrigin = nil
    }

    // MARK: - Toggle main window

    func toggleMainWindow() {
        let mainWindow = NSApp.windows.first { !($0 is NSPanel) }
        if let win = mainWindow {
            if win.isVisible {
                win.orderOut(nil)
            } else {
                win.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        } else {
            // Window was closed — reopen via WindowGroup
            NSApp.sendAction(Selector(("_openNewWindowAction:")), to: nil, from: nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Menu actions

    @objc private func menuOpenApp() {
        toggleMainWindow()
    }

    @objc private func menuTogglePin() {
        isPinned.toggle()
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }

    private func positionTopRight(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let margin: CGFloat = 20
        let x = screen.visibleFrame.maxX - panelWidth - margin
        let y = screen.visibleFrame.maxY - 38 - margin
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - NSMenuDelegate (update checkmark on open)

extension MiniWindowManager: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if let pinItem = menu.item(withTag: 1) {
            pinItem.title = isPinned ? "✓ 窗口置顶" : "  窗口置顶"
        }
    }
}
