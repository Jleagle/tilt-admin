// Sources/TiltAdmin/TiltAdminApp.swift
import SwiftUI
import TiltAdminLib

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when window closes — keep running in menu bar
        // But switch to accessory mode so we hide from Dock
        DispatchQueue.main.async {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
        return false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // When activated (e.g. opening main window), ensure we're a regular app
        // so we can receive keyboard focus
        if NSApplication.shared.windows.contains(where: { $0.isVisible && !$0.className.contains("StatusBar") }) {
            NSApplication.shared.setActivationPolicy(.regular)
        }
    }
}

@main
struct TiltAdminApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var manager = TiltManager()

    var body: some Scene {
        Window("Tilt Admin", id: "main") {
            MainWindow()
                .environment(manager)
                .task { manager.initialize() }
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate()
                }
        }

        MenuBarExtra("Tilt Admin", systemImage: "arrow.triangle.2.circlepath") {
            MenuBarPopover()
                .environment(manager)
        }
        .menuBarExtraStyle(.window)
    }
}
