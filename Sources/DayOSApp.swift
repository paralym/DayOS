import SwiftUI
import UserNotifications

@main
struct DayOSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = TodoStore()
    @StateObject private var noteStore = NoteStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(noteStore)
                .frame(
                    minWidth: 680,
                    idealWidth: 780,
                    minHeight: TerminalTheme.windowHeight,
                    idealHeight: TerminalTheme.windowHeight
                )
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .help) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NotificationManager.shared.setup()
        NotificationManager.shared.requestPermission()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // keep alive when main window is closed; mini capsule stays visible
    }
}
