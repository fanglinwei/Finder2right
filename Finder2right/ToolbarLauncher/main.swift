import AppKit

final class LauncherDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let appURL = Bundle.main.bundleURL.deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        guard Bundle(url: appURL)?.bundleIdentifier == "local.finder2right",
              let url = URL(string: "finder2right://toolbar") else {
            NSAlert(error: NSError(domain: "Finder2right", code: 9, userInfo: [
                NSLocalizedDescriptionKey: "请使用 Finder2right App 内置的工具栏启动器。"
            ])).runModal()
            NSApp.terminate(nil)
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        configuration.allowsRunningApplicationSubstitution = false
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration) { _, error in
            DispatchQueue.main.async {
                if let error {
                    NSApp.activate(ignoringOtherApps: true)
                    NSAlert(error: error).runModal()
                }
                NSApp.terminate(nil)
            }
        }
    }
}

let application = NSApplication.shared
let delegate = LauncherDelegate()
application.setActivationPolicy(.accessory)
application.delegate = delegate
application.run()
