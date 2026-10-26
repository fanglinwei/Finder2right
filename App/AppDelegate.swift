import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = FileTypeStore()
    private var mainWindow: NSWindow?
    private var isHandlingRequest = false
    private var hasReceivedRequest = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Launch Services delivers URL events during startup; defer the ordinary launch window.
        DispatchQueue.main.async { [self] in
            if !hasReceivedRequest { showMainWindow() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !isHandlingRequest { showMainWindow() }
        return false
    }

    private func showMainWindow() {
        if mainWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: MainView(store: store)))
            window.title = "Finder2right"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.toolbarStyle = .unifiedCompact
            window.setContentSize(NSSize(width: 720, height: 414))
            window.isReleasedWhenClosed = false
            window.center()
            mainWindow = window
        }
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first, let request = FinderRequest(url: url) else { return }
        hasReceivedRequest = true
        isHandlingRequest = true
        mainWindow?.close()
        mainWindow = nil
        if request.action == .openTerminal {
            openTerminal(directory: request.directory)
            return
        }
        defer { finishRequest() }
        do {
            switch request.action {
            case .createFile(let typeID):
                guard let type = try FileTypes.load().first(where: { $0.id == typeID && $0.isEnabled }) else {
                    throw NSError(domain: "Finder2right", code: 3, userInfo: [NSLocalizedDescriptionKey: "该文件类型已停用或删除，请重新展开新建菜单。"])
                }
                let directory = try FileCreation.directory(from: request.directory)
                createFile(type: type, directory: directory)
            case .runCommand(let id):
                try runTerminalCommand(id: id, directory: request.directory)
            case .openTerminal:
                break
            }
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            NSAlert(error: error).runModal()
        }
    }

    private func openTerminal(directory: URL) {
        do {
            let directory = try FileCreation.directory(from: directory)
            guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
                throw NSError(domain: "Finder2right", code: 4, userInfo: [NSLocalizedDescriptionKey: "找不到系统终端 App。"])
            }
            NSWorkspace.shared.open([directory], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                DispatchQueue.main.async {
                    if let error {
                        NSApp.activate(ignoringOtherApps: true)
                        NSAlert(error: error).runModal()
                    }
                    self.finishRequest()
                }
            }
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            NSAlert(error: error).runModal()
            finishRequest()
        }
    }

    private func finishRequest() {
        isHandlingRequest = false
        NSApp.terminate(nil)
    }

    private func runTerminalCommand(id: UUID, directory: URL) throws {
        let directory = try FileCreation.directory(from: directory)
        guard let command = try TerminalCommands.load().first(where: { $0.id == id && $0.isEnabled }) else {
            throw NSError(domain: "Finder2right", code: 6, userInfo: [NSLocalizedDescriptionKey: "该命令已停用或删除，请重新展开终端命令菜单。"])
        }
        guard let script = NSAppleScript(source: TerminalCommands.appleScript(command: command.command, directory: directory)) else {
            throw NSError(domain: "Finder2right", code: 7, userInfo: [NSLocalizedDescriptionKey: "无法创建终端运行请求。"])
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "终端运行请求失败。"
            throw NSError(domain: "Finder2right", code: 8, userInfo: [
                NSLocalizedDescriptionKey: "\(message)\n若未允许控制 Terminal，请在系统设置 → 隐私与安全性 → 自动化中为 Finder2right 开启终端权限。"
            ])
        }
    }

    private func createFile(type: FileType, directory: URL) {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSSavePanel()
        panel.title = "新建\(type.name)"
        panel.prompt = "创建"
        panel.nameFieldStringValue = "未命名.\(type.fileExtension)"
        panel.directoryURL = directory
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = [.data]
        panel.allowsOtherFileTypes = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try FileCreation.create(at: url)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            let alert = NSAlert(error: error)
            alert.informativeText = "文件未创建，已有文件不会被覆盖。\n\(error.localizedDescription)"
            alert.runModal()
        }
    }
}
