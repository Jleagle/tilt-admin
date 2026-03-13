// Sources/TiltAdmin/TiltAdminApp.swift
import SwiftUI
import TiltAdminLib

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
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
        }

        MenuBarExtra("Tilt Admin", systemImage: "arrow.triangle.2.circlepath") {
            MenuBarPopover()
                .environment(manager)
        }
        .menuBarExtraStyle(.window)
    }
}
