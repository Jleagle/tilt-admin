// Sources/TiltAdmin/TiltAdminApp.swift
import SwiftUI
import TiltAdminLib

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let source = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = makeSquircleIcon(from: source)
        }
    }

    private func makeSquircleIcon(from source: NSImage, size: CGFloat = 1024) -> NSImage {
        let icon = NSImage(size: NSSize(width: size, height: size))
        icon.lockFocus()

        // Apple's macOS icon squircle: ~22.37% corner radius with continuous curves
        let rect = NSRect(x: size * 0.05, y: size * 0.05, width: size * 0.9, height: size * 0.9)
        let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.2237, yRadius: rect.height * 0.2237)

        // White background
        NSColor.white.setFill()
        path.fill()

        // Clip to squircle and draw the source image
        path.addClip()
        source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)

        // Subtle border
        NSColor(white: 0, alpha: 0.1).setStroke()
        path.lineWidth = size * 0.005
        path.stroke()

        icon.unlockFocus()
        return icon
    }

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
