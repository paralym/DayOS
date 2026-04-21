import AppKit
import SwiftUI
import QuartzCore

// MARK: - Screen helper

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

// MARK: - Settings

class FocusOverlaySettings: ObservableObject {
    static let shared = FocusOverlaySettings()

    @Published var opacity: Double {
        didSet { UserDefaults.standard.set(opacity, forKey: "focusOpacity") }
    }
    @Published var gradientEdge: Double {
        didSet { UserDefaults.standard.set(gradientEdge, forKey: "focusGradientEdge") }
    }
    /// nil means "all screens enabled" (default). Once user explicitly picks, stored as array.
    @Published var enabledDisplayIDs: Set<CGDirectDisplayID>? {
        didSet {
            if let ids = enabledDisplayIDs {
                UserDefaults.standard.set(ids.map { Int($0) }, forKey: "focusEnabledDisplays")
            } else {
                UserDefaults.standard.removeObject(forKey: "focusEnabledDisplays")
            }
        }
    }

    private init() {
        let o = UserDefaults.standard.double(forKey: "focusOpacity")
        opacity = o > 0 ? o : 0.42
        let g = UserDefaults.standard.double(forKey: "focusGradientEdge")
        gradientEdge = g > 0 ? g : 0.4

        if let saved = UserDefaults.standard.array(forKey: "focusEnabledDisplays") as? [Int] {
            enabledDisplayIDs = Set(saved.map { CGDirectDisplayID($0) })
        } else {
            enabledDisplayIDs = nil  // all
        }
    }

    func isEnabled(_ id: CGDirectDisplayID) -> Bool {
        enabledDisplayIDs == nil || enabledDisplayIDs!.contains(id)
    }

    func toggleDisplay(_ id: CGDirectDisplayID) {
        if enabledDisplayIDs == nil {
            // First explicit choice: start from "all enabled"
            enabledDisplayIDs = Set(NSScreen.screens.compactMap { $0.displayID })
        }
        if enabledDisplayIDs!.contains(id) {
            enabledDisplayIDs!.remove(id)
        } else {
            enabledDisplayIDs!.insert(id)
        }
    }
}

// MARK: - Overlay view

private struct FocusOverlayView: View {
    @ObservedObject var settings = FocusOverlaySettings.shared

    var body: some View {
        GeometryReader { geo in
            let r = max(geo.size.width, geo.size.height) * 0.75
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .clear, location: settings.gradientEdge),
                    .init(color: .black.opacity(settings.opacity), location: 1.0)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: r
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Manager

class FocusOverlayManager: NSObject {
    static let shared = FocusOverlayManager()

    private var panels: [CGDirectDisplayID: NSPanel] = [:]
    private(set) var isVisible = false

    func setup() {
        for screen in NSScreen.screens {
            addPanel(for: screen)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screensChanged() {
        let currentIDs = Set(NSScreen.screens.compactMap { $0.displayID })
        // Add new screens
        for screen in NSScreen.screens where panels[screen.displayID ?? 0] == nil {
            addPanel(for: screen)
            if isVisible, let id = screen.displayID,
               FocusOverlaySettings.shared.isEnabled(id) {
                panels[id]?.alphaValue = 1
                panels[id]?.orderFront(nil)
            }
        }
        // Remove disconnected screens
        for id in panels.keys where !currentIDs.contains(id) {
            panels[id]?.orderOut(nil)
            panels.removeValue(forKey: id)
        }
    }

    private func addPanel(for screen: NSScreen) {
        guard let id = screen.displayID, panels[id] == nil else { return }
        let hosting = NSHostingView(rootView: FocusOverlayView())
        let p = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.alphaValue = 0
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        p.level = .floating
        p.contentView = hosting
        panels[id] = p
    }

    func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible

        for (displayID, panel) in panels {
            guard FocusOverlaySettings.shared.isEnabled(displayID) else {
                panel.orderOut(nil)
                continue
            }
            if let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) {
                panel.setFrame(screen.frame, display: false)
            }
            if visible {
                panel.orderFront(nil)
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.6
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    panel.animator().alphaValue = 1
                }
            } else {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.36
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    panel.animator().alphaValue = 0
                } completionHandler: { [weak self] in
                    if self?.isVisible == false { panel.orderOut(nil) }
                }
            }
        }
    }

    /// Call when user toggles a display in Settings — apply immediately.
    func refreshVisibility() {
        guard isVisible else { return }
        for (displayID, panel) in panels {
            if FocusOverlaySettings.shared.isEnabled(displayID) {
                if let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) {
                    panel.setFrame(screen.frame, display: false)
                }
                panel.orderFront(nil)
                panel.alphaValue = 1
            } else {
                panel.alphaValue = 0
                panel.orderOut(nil)
            }
        }
    }
}
